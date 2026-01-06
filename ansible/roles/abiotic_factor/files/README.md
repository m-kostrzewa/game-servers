# Abiotic Factor World Save Files

Place your world save .7z file in this directory.

The Ansible role will automatically deploy this file to the server's save directory on first deployment.

## Expected file format:
- Filename: `<your-world-name>.7z` (7-Zip archive of `AppData\Local\AbioticFactor\Saved\SaveGames\123xxx\Worlds\YourWorldName` directory)
- Contents: Your Abiotic Factor world save data

## Note:
The world save will only be uploaded if it doesn't already exist on the server, preventing accidental overwrites of active game progress.
