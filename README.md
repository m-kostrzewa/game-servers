# Nebulous Fleet Command Server Management

Ansible-based deployment system for multi-server N:FC game server orchestration with automated updates, restarts, monitoring (Prometheus/Grafana), and log aggregation (Promtail/Loki).

**Status**: Operational | **Servers**: 2 (nds2: EU-1, nds3: EU-2) | **Monitoring**: Grafana Cloud

## Quick Start

### Prerequisites
- **Windows**: PowerShell 5.1+
- **WSL2**: Ubuntu distribution with Ansible 2.16+
- **Remote servers**: Ubuntu 24.04 with Docker and **N:FC server installed via [VoodooFan's script](https://github.com/VoodooFan/nebulous/blob/main/install-steam-and-nds.bash)**
- **Monitoring**: Free-tier [Grafana Cloud](https://grafana.com/products/cloud/) account (optional)

### Initial Setup

```powershell
# 1. Copy vault template
cd ansible
cp inventory/group_vars/nds_servers/vault.yml.template inventory/group_vars/nds_servers/vault.yml

# 2. Edit vault with your secrets (admin password, admin steam id, Grafana endpoints)
.\nebctl.ps1 edit-vault

# 3. Verify setup
.\nebctl.ps1 verify

# 4. Test on safe target (dry-run)
.\nebctl.ps1 deploy-test -DryRun
```

### Deploy

```powershell
# All servers
.\nebctl.ps1 deploy-all

# Single server (safe for updates)
.\nebctl.ps1 deploy-nds2

# Dry-run (preview only, no changes)
.\nebctl.ps1 deploy-all -DryRun
```

## Key Features

- **Encrypted secrets**: Ansible Vault (`vault.yml` - encrypted at rest)
- **Flexible inventory**: YAML-based, easy to add/modify servers
- **Jinja2 templates**: Dynamic config generation (nds.conf, prometheus.yml, config.yaml, crontab)
- **Graceful restarts**: ServerCommand.xml protocol (no mid-match disruptions)
- **Automated checks**: Hourly update check, daily 08:05 UTC restart (cron)
- **Full monitoring**: Prometheus metrics + Promtail logs → Grafana Cloud
- **Multi-server**: Deploy to specific servers with `--limit` flag

## Repository Structure

```
.
├── nebctl.ps1                      # PowerShell deployment wrapper
├── ansible/
│   ├── playbook.yml                # Main orchestration
│   ├── inventory/hosts.yml         # Server inventory + per-host vars
│   ├── inventory/group_vars/nds_servers/
│   │   ├── vars.yml                # Shared variables (ports, paths)
│   │   ├── vault.yml               # Encrypted secrets (edit with: .\nebctl.ps1 edit-vault)
│   │   └── vault.yml.template      # Template (rename to vault.yml and fill in)
│   ├── roles/
│   │   ├── nds_server/             # Game server deployment
│   │   ├── system_config/          # Cron, sudoers, permissions
│   │   └── monitoring/             # Prometheus, Promtail, Node Exporter
│   ├── templates/
│   │   ├── nds.conf.j2             # Server config (XML)
│   │   ├── prometheus.yml.j2       # Metrics collection
│   │   ├── config.yaml.j2          # Log aggregation
│   │   └── crontab.j2              # Scheduled tasks
│   └── README.md                   # Full Ansible documentation
├── grafana/
│   ├── Nebulous-*.json             # Pre-built dashboards
│   └── Maps played-*.json          # Game statistics dashboard
└── .github/
    └── copilot-instructions.md     # Comprehensive project guide for AI
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
| **Deploy single** | `.\nebctl.ps1 deploy-nds3` |
| **Dry-run (preview)** | `.\nebctl.ps1 deploy-all -DryRun` |

## Monitoring

- **Metrics**: Prometheus scrapes node-exporter + game server events → Grafana Cloud
- **Logs**: Promtail ships 3 log streams (system, game, admin) → Grafana Loki
- **Dashboards**: Import `grafana/*.json` files into Grafana Cloud UI

## Credits

- Installation helper: [VoodooFan's script](https://github.com/VoodooFan/nebulous)
