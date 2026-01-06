# Abiotic Factor Dedicated Server Role

This Ansible role deploys an Abiotic Factor dedicated server on Ubuntu using SteamCMD.

## Overview

Based on the installation guides:
- **Quickstart**: https://github.com/DFJacob/AbioticFactorDedicatedServer/wiki/Guide-%E2%80%90-Quickstart
- **Linux Setup**: https://github.com/DFJacob/AbioticFactorDedicatedServer/issues/3#issuecomment-2094369127

## Features

- ✓ Automated SteamCMD installation and configuration
- ✓ Dependencies installation (lib32gcc-s1, xvfb, p7zip-full)
- ✓ Systemd service creation and management
- ✓ Server configuration via Game.ini template
- ✓ World save deployment (only if not exists - prevents overwriting active saves)
- ✓ Automatic server restarts on failure

## Directory Structure

```
ansible/roles/abiotic_factor/
├── tasks/
│   └── main.yml              # Installation and configuration tasks
├── handlers/
│   └── main.yml              # Service restart handler
├── templates/
│   ├── abiotic-factor.service.j2  # Systemd service template
│   └── Game.ini.j2           # Server configuration template
└── files/
    ├── README.md             # Instructions for world save files
    └── <your-world>.7z       # Place your world save here
```

## Installation Paths

| Component | Path |
|-----------|------|
| Install directory | `/srv/steam/abiotic-factor` |
| Config directory | `/srv/steam/abiotic-factor/AbioticFactor/Saved/Config/LinuxServer` |
| Saves directory | `/srv/steam/abiotic-factor/AbioticFactor/Saved/SaveGames` |
| SteamCMD | `/srv/steam/steamcmd` |

## Configuration Variables

Set these in `ansible/inventory/group_vars/abiotic_servers/vars.yml`.

## World Save Deployment

1. **Place your world save** as a `.7z` file in `ansible/roles/abiotic_factor/files/`
2. **Update vars.yml** to set `abiotic_world_file: "YourWorld.7z"`
3. **Deploy**: The role will:
   - Check if the save already exists on the server
   - Upload and extract only if not present
   - Preserve existing saves to prevent data loss

**Important**: The world save is only deployed on initial setup. Re-running the playbook won't overwrite active saves.

## Deployment

### Deploy Abiotic Factor to nds3

```powershell
.\nebctl.ps1 deploy-abiotic
```

### Dry-run (preview changes)

```powershell
.\nebctl.ps1 deploy-abiotic -DryRun
```

## Network Configuration

Ensure these ports are open on your server firewall:

| Port | Protocol | Purpose |
|------|----------|---------|
| 7778 | UDP | Game traffic |
| 27015 | UDP | Query port (server browser) |

### World save not loading

1. Verify the .7z file is in `ansible/roles/abiotic_factor/files/`
2. Check `abiotic_world_file` variable is set correctly
3. SSH to server and check `/srv/steam/abiotic-factor/AbioticFactor/Saved/SaveGames/`
4. Manually extract if needed:
   ```bash
   cd /srv/steam/abiotic-factor/AbioticFactor/Saved/SaveGames/
   7z x YourWorld.7z
   ```

## References

- **Steam App ID**: 2857140 (Abiotic Factor Dedicated Server)
- **Game**: https://store.steampowered.com/app/2857140/
- **Server Guide**: https://github.com/DFJacob/AbioticFactorDedicatedServer
- **Linux Setup**: https://github.com/DFJacob/AbioticFactorDedicatedServer/issues/3
