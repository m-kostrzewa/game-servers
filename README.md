# DEPRECATED

This repo was moved to https://github.com/m-kostrzewa/game-servers.

# Game Server Management

Ansible-based deployment system for game servers with automated updates, monitoring, and configuration management.

## Quick Start

```powershell
# 1. Copy vault template
cd ansible
cp inventory/group_vars/nds_servers/vault.yml.template inventory/group_vars/nds_servers/vault.yml

# 2. Edit vault with your secrets
.\nebctl.ps1 edit-vault

# 3. Deploy
.\nebctl.ps1 deploy-all

# Or deploy specific games
.\nebctl.ps1 deploy-one alpha    # Nebulous server
.\nebctl.ps1 deploy-abiotic      # Abiotic Factor server
```

## Game-Specific Documentation

- **Nebulous Fleet Command**: See `ansible/roles/nds_server/README.md`
- **Abiotic Factor**: See `ansible/roles/abiotic_factor/README.md`
- **Automated checks**: Hourly update check, daily 08:05 UTC restart (cron)
- **Full monitoring**: Prometheus metrics + Promtail logs → Grafana Cloud
- **Multi-server**: Deploy to specific servers with `--limit` flag

## Repository Structure

```
ansible/
├── playbook-nebulous.yml       # Nebulous deployment
├── playbook-abiotic.yml        # Abiotic Factor deployment
├── inventory/hosts.yml         # Server inventory
├── inventory/group_vars/       # Variables and vault
└── roles/
    ├── nds_server/             # Nebulous server
    ├── abiotic_factor/         # Abiotic Factor server
    ├── system_config/          # Cron, sudoers
    └── monitoring/             # Prometheus, Promtail
```

## Vault Password (Non-Interactive)

Create `.vault_pass.txt` in repo root (gitignored) for automated runs:

```powershell
# Creates password file (Windows PowerShell)
'your-vault-password' | Out-File -Encoding UTF8 -FilePath .vault_pass.txt
```

`nebctl.ps1` will use this automatically.

## Common Tasks

| Task | Command |
|------|---------|
| **List servers & vars** | `.\nebctl.ps1 verify` |
| **Test SSH connectivity** | `.\nebctl.ps1 check` |
| **Edit vault secrets** | `.\nebctl.ps1 edit-vault` |
| **View encrypted vault** | `.\nebctl.ps1 view-vault` |
| **Deploy all** | `.\nebctl.ps1 deploy-all` |
| **Deploy single** | `.\nebctl.ps1 deploy-one bravo` |
| **Dry-run (preview)** | `.\nebctl.ps1 deploy-all -DryRun` |

## Monitoring

- **Metrics**: Prometheus scrapes node-exporter + game server events → Grafana Cloud
- **Logs**: Promtail ships 3 log streams (system, game, admin) → Grafana Loki
- **Dashboards**: Import `grafana/*.json` files into Grafana Cloud UI

## Credits

- Installation helper: [VoodooFan's script](https://github.com/VoodooFan/nebulous)
- Reboot utility: [Switchback's N:FC Automatic Server Reboot Utility](https://github.com/switchback028/N-FE-ASRU)
