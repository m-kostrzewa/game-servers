<#
Generic management wrapper for Ansible operations (renamed from ansible-deploy.ps1).
Usage: .\nebctl.ps1 <command>
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("deploy-all", "deploy-test", "deploy-one", "verify", "check", "edit-vault", "view-vault", "update-dashboards")]
    [string]$Command = "deploy-all",
    
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Server = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ansibleDir = Join-Path $PSScriptRoot "ansible"
$vaultPassFile = Join-Path $PSScriptRoot ".vault_pass.txt"
$wslVaultPassFile = ($vaultPassFile -replace "C:\\", "/mnt/c/" -replace "\\", "/")

function Invoke-WSLAnsible {
    param(
        [string]$Arguments,
        [string]$WorkDir = $ansibleDir
    )
    
    $wslPath = ($WorkDir -replace "C:\\", "/mnt/c/" -replace "\\", "/")
    
    # Copy vault password to /tmp to avoid executable bit issues
    $copyCmd = "cat '$wslVaultPassFile' > /tmp/vault_pass.txt && chmod 600 /tmp/vault_pass.txt"
    wsl -d Ubuntu -- bash -c $copyCmd | Out-Null
    
    # Replace vault password file reference in arguments
    $Arguments = $Arguments -replace [regex]::Escape("'$wslVaultPassFile'"), "/tmp/vault_pass.txt"
    
    $wslCmd = "cd '$wslPath' && $Arguments"
    
    Write-Host "Executing in WSL: $Arguments" -ForegroundColor Cyan
    wsl -d Ubuntu -- bash -c $wslCmd
}

switch ($Command) {
    "deploy-all" {
        Write-Host "[DEPLOY] Deploying to all servers (nds2, nds3)..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook --inventory inventory/hosts.yml playbook.yml --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "deploy-test" {
        Write-Host "[TEST] Deploying to nds3 (test server only)..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook --inventory inventory/hosts.yml playbook.yml --limit nds3 --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "deploy-one" {
        if (-not $Server) {
            Write-Host "[ERROR] deploy-one requires a server name (e.g., alpha or bravo)" -ForegroundColor Red
            break
        }
        $limitTarget = switch ($Server.ToLower()) {
            "alpha" { "nds2" }
            "bravo" { "nds3" }
            default { $Server }
        }
        Write-Host "[DEPLOY] Deploying to $Server (limit=$limitTarget)..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook --inventory inventory/hosts.yml playbook.yml --limit $limitTarget --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "verify" {
        Write-Host "[VERIFY] Listing inventory..." -ForegroundColor Green
        Invoke-WSLAnsible "ansible-inventory --inventory inventory/hosts.yml --vault-password-file '$wslVaultPassFile' --list"
    }
    
    "check" {
        Write-Host "[CHECK] Testing SSH connectivity..." -ForegroundColor Green
        Invoke-WSLAnsible "ansible all --inventory inventory/hosts.yml --vault-password-file '$wslVaultPassFile' -m ping"
    }
    
    "edit-vault" {
        Write-Host "[VAULT] Opening vault editor..." -ForegroundColor Green
        Invoke-WSLAnsible "ansible-vault edit --vault-password-file '$wslVaultPassFile' inventory/group_vars/nds_servers/vault.yml"
    }
    
    "view-vault" {
        Write-Host "[VAULT] Viewing encrypted vault (read-only)..." -ForegroundColor Green
        Invoke-WSLAnsible "ansible-vault view --vault-password-file '$wslVaultPassFile' inventory/group_vars/nds_servers/vault.yml"
    }
    
    "update-dashboards" {
        Write-Host "[GRAFANA] Updating Grafana Cloud dashboards..." -ForegroundColor Green
        
        # Extract Grafana credentials from vault
        $vaultContent = wsl -d Ubuntu -- bash -c "cat '$wslVaultPassFile' > /tmp/vault_pass.txt && chmod 600 /tmp/vault_pass.txt && cd '$($ansibleDir -replace 'C:\\', '/mnt/c/' -replace '\\', '/')' && ansible-vault view --vault-password-file /tmp/vault_pass.txt inventory/group_vars/nds_servers/vault.yml"
        
        $grafanaUrl = ($vaultContent | Select-String 'vault_grafana_url:\s*"?([^"]+)"?' | ForEach-Object { $_.Matches.Groups[1].Value })
        $grafanaToken = ($vaultContent | Select-String 'vault_grafana_token:\s*"?([^"]+)"?' | ForEach-Object { $_.Matches.Groups[1].Value })
        
        # Remove trailing slash from URL if present
        $grafanaUrl = $grafanaUrl.TrimEnd('/')
        
        if (-not $grafanaUrl -or -not $grafanaToken) {
            Write-Host "[ERROR] Grafana credentials not found in vault. Add vault_grafana_url and vault_grafana_token." -ForegroundColor Red
            Write-Host "Example vault entries:" -ForegroundColor Yellow
            Write-Host '  vault_grafana_url: "https://yourinstance.grafana.net"' -ForegroundColor Cyan
            Write-Host '  vault_grafana_token: "glsa_xxxxxxxxxxxx"' -ForegroundColor Cyan
            break
        }
        
        $dashboardDir = Join-Path $PSScriptRoot "grafana"
        $dashboards = Get-ChildItem -Path $dashboardDir -Filter "*.json"
        
        foreach ($dashboard in $dashboards) {
            Write-Host "  Uploading $($dashboard.Name)..." -ForegroundColor Cyan
            $dashboardJson = Get-Content $dashboard.FullName -Raw | ConvertFrom-Json
            
            # Remove id and uid to let Grafana assign them (for updates, use existing uid)
            $dashboardJson.PSObject.Properties.Remove('id')
            
            # Wrap in Grafana API format
            $payload = @{
                dashboard = $dashboardJson
                overwrite = $true
                message = "Updated via nebctl.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            } | ConvertTo-Json -Depth 100
            
            $headers = @{
                "Authorization" = "Bearer $grafanaToken"
                "Content-Type" = "application/json"
            }
            
            Write-Host "    Debug: POST $grafanaUrl/api/dashboards/db" -ForegroundColor Gray
            
            try {
                $response = Invoke-RestMethod -Uri "$grafanaUrl/api/dashboards/db" -Method Post -Headers $headers -Body $payload
                Write-Host "    [OK] $($dashboard.Name) updated (UID: $($response.uid))" -ForegroundColor Green
            } catch {
                Write-Host "    [FAIL] Failed: $($_.Exception.Message)" -ForegroundColor Red
                if ($_.ErrorDetails.Message) {
                    Write-Host "    Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    default {
        Write-Host "[ERROR] Unknown command: $Command" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available commands:" -ForegroundColor Yellow
        Write-Host "  deploy-all     - Deploy to all servers" -ForegroundColor Yellow
        Write-Host "  deploy-test    - Deploy to neb3 only (for testing)" -ForegroundColor Yellow
        Write-Host "  deploy-one     - Deploy to a single server (pass server name)" -ForegroundColor Yellow
        Write-Host "  verify         - List inventory" -ForegroundColor Yellow
        Write-Host "  check          - Test SSH connectivity" -ForegroundColor Yellow
        Write-Host "  edit-vault     - Edit encrypted vault secrets" -ForegroundColor Yellow
        Write-Host "  view-vault     - View encrypted vault (read-only)" -ForegroundColor Yellow
        Write-Host "  update-dashboards - Upload Grafana dashboards from grafana/ folder" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  -DryRun        - Run with --check (no changes)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Green
        Write-Host "  .\nebctl.ps1 deploy-all" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 deploy-test -DryRun" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 deploy-one neb3" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 update-dashboards" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 edit-vault" -ForegroundColor Cyan
    }
}
