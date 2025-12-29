<#
Generic management wrapper for Ansible operations (renamed from ansible-deploy.ps1).
Usage: .\nebctl.ps1 <command>
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("deploy-all", "deploy-test", "deploy-nds2", "deploy-nds3", "verify", "check", "edit-vault", "view-vault")]
    [string]$Command = "deploy-all",
    
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
        Invoke-WSLAnsible "ansible-playbook playbook.yml --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "deploy-test" {
        Write-Host "[TEST] Deploying to nds3 (test server only)..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook playbook.yml --limit nds3 --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "deploy-nds2" {
        Write-Host "[DEPLOY] Deploying to nds2 only..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook playbook.yml --limit nds2 --vault-password-file '$wslVaultPassFile' $dryRunFlag"
    }
    
    "deploy-nds3" {
        Write-Host "[DEPLOY] Deploying to nds3 only..." -ForegroundColor Green
        $dryRunFlag = if ($DryRun) { "--check" } else { "" }
        Invoke-WSLAnsible "ansible-playbook playbook.yml --limit nds3 --vault-password-file '$wslVaultPassFile' $dryRunFlag"
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
    
    default {
        Write-Host "[ERROR] Unknown command: $Command" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available commands:" -ForegroundColor Yellow
        Write-Host "  deploy-all     - Deploy to all servers (nds2, nds3)" -ForegroundColor Yellow
        Write-Host "  deploy-test    - Deploy to nds3 only (for testing)" -ForegroundColor Yellow
        Write-Host "  deploy-nds2    - Deploy to nds2 only" -ForegroundColor Yellow
        Write-Host "  deploy-nds3    - Deploy to nds3 only" -ForegroundColor Yellow
        Write-Host "  verify         - List inventory" -ForegroundColor Yellow
        Write-Host "  check          - Test SSH connectivity" -ForegroundColor Yellow
        Write-Host "  edit-vault     - Edit encrypted vault secrets" -ForegroundColor Yellow
        Write-Host "  view-vault     - View encrypted vault (read-only)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  -DryRun        - Run with --check (no changes)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Green
        Write-Host "  .\nebctl.ps1 deploy-all" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 deploy-test -DryRun" -ForegroundColor Cyan
        Write-Host "  .\nebctl.ps1 edit-vault" -ForegroundColor Cyan
    }
}
