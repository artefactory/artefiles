# azure: Azure CLI

- macOS brew `azure-cli`; Linux `uv tool install --upgrade azure-cli`.
- First use: `az login` (opens a browser; `az login --use-device-code` on a
  remote machine), then `az account set --subscription <name or id>`.
- `az account show` shows the current subscription; `az group list -o table`.
- AKS: `az aks get-credentials -g <group> -n <cluster>`; use kubectl from the
  `kubernetes` module.
- Upgrade: `brew upgrade azure-cli` (macOS) or `uv tool upgrade azure-cli`.
- Doctor: checks `az`.
- Who is signed in, and what to run if nobody is: `scripts/cloud-status.sh`.
