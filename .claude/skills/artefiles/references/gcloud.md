# gcloud: Google Cloud CLI

- macOS cask `gcloud-cli` (fish adds it to PATH and loads its completion on the
  first `gcloud` command). Linux: installed in `~/.local/google-cloud-sdk`; a
  rerun runs `gcloud components update`.
- First use: `gcloud init` (account and default project), then
  `gcloud auth application-default login` for client libraries.
- `gcloud config set project <id>`; `gcloud config configurations list` for
  several accounts.
- GKE: `gcloud components install gke-gcloud-auth-plugin` (Linux installs it),
  then `gcloud container clusters get-credentials <cluster>`; use kubectl from
  the `kubernetes` module.
- Doctor: checks `gcloud`.
- Who is signed in, and what to run if nobody is: `scripts/cloud-status.sh`.
