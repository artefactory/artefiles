# kubernetes: kubectl and k9s

- macOS brew `kubernetes-cli` and `k9s`. Linux: kubectl downloaded to
  `~/.local/bin` when it is not the current stable release; k9s from its
  release.
- Get a cluster's credentials with the cloud CLI (`gcloud container clusters
  get-credentials`, `az aks get-credentials`), then:
  - `kubectl config get-contexts`, `kubectl config use-context <name>`;
  - `kubectl get pods -A`, `kubectl logs -f <pod>`, `kubectl describe pod <pod>`.
- k9s: `k9s` opens a terminal UI on the current context. `:pods`, `:deploy`,
  `:svc` switch views, `/` filters, `l` logs, `d` describe, `s` shell,
  `?` lists the keys, `:q` quits.
- Doctor: checks `kubectl` and `k9s`.
- Who is signed in, and what to run if nobody is: `scripts/cloud-status.sh`.
