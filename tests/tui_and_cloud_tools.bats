#!/usr/bin/env bats
# The azure, kubernetes and data modules, and the terminal UIs that join the
# module of the tool they drive: lazygit (git_advanced), lazydocker and the
# docker buildx plugin (containers), k9s (kubernetes), harlequin (data).

setup() {
  load 'helpers/setup'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl
DOCTOR=dot_config/fish/functions/dotfiles_doctor.fish.tmpl
AZ_SCRIPT=.chezmoiscripts/linux/run_onchange_after_install-azure-cli.sh
KUBECTL_SCRIPT=.chezmoiscripts/linux/run_onchange_install-kubectl.sh
HARLEQUIN_SCRIPT=.chezmoiscripts/run_onchange_after_zzzzz_install-harlequin.sh
BUILDX_TMPL=.chezmoiscripts/darwin/run_onchange_after_link-docker-buildx.sh.tmpl

# render MODULES_JSON FILE — FILE rendered for a home with these modules.
render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  chezmoi_render "$H" "$2"
}

# linux_render MODULES_JSON FILE — FILE rendered as on Linux.
linux_render() {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/$RANDOM")
  seed_chezmoi_config "$H" "{\"modules\":$1}"
  XDG_CONFIG_HOME="$H/.config" HOME="$H" chezmoi execute-template \
    --config "$H/.config/chezmoi/chezmoi.toml" --source "$REPO_ROOT" --destination "$H" \
    < <(sed 's/eq \.chezmoi\.os "linux"/true/' "$REPO_ROOT/$2")
}

brews() { render "$1" "$DARWIN_TMPL"; }

# uv_stub — a uv in $H/.local/bin that logs its calls to $CALLS.
uv_stub() {
  H="$BATS_TEST_TMPDIR/h"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$H/.local/bin"
  printf '#!/bin/sh\necho "uv $*" >> "%s"\n' "$CALLS" > "$H/.local/bin/uv"
  chmod +x "$H/.local/bin/uv"
}

@test "the init prompt offers azure, kubernetes and data, none checked by default" {
  for m in azure kubernetes data; do
    prompt_module_names | grep -qx "$m"
    # shellcheck disable=SC2016 # the pattern matches a literal `$defaults`
    [ "$(grep -c "^# \[\[ \$defaults := list.*\"$m\"" "$REPO_ROOT/.chezmoi.toml.tmpl")" -eq 0 ]
  done
  [[ "$(prompt_help azure)" == *"Azure CLI"* ]]
  [[ "$(prompt_help kubernetes)" == *kubectl*k9s* ]]
  [[ "$(prompt_help data)" == *DuckDB*harlequin* ]]
}

@test "azure installs the azure-cli brew on macOS, only when selected" {
  [ "$(yq -r '.packages.darwin.modules.azure.brews[0]' "$REPO_ROOT/$PKG")" = azure-cli ]
  brews '["azure"]' | grep -qxF 'brew "azure-cli"'
  [ "$(brews '[]' | grep -c 'azure-cli')" -eq 0 ]
}

@test "on Linux, the azure script installs or upgrades az with uv" {
  uv_stub
  run env -i HOME="$H" PATH=/usr/bin:/bin sh "$REPO_ROOT/$AZ_SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx 'uv tool install --upgrade azure-cli' "$CALLS"
}

@test "on Linux, each module script runs only when its module is selected" {
  for pair in azure:install-azure-cli.sh kubernetes:install-kubectl.sh; do
    m=${pair%%:*} target=.chezmoiscripts/linux/${pair#*:}
    linux_render '[]' .chezmoiignore | grep -qxF "$target"
    [ "$(linux_render "[\"$m\"]" .chezmoiignore | grep -cxF "$target")" -eq 0 ]
  done
}

@test "the harlequin script runs only with data, on every OS" {
  render '[]' .chezmoiignore | grep -qxF .chezmoiscripts/zzzzz_install-harlequin.sh
  [ "$(render '["data"]' .chezmoiignore | grep -cxF .chezmoiscripts/zzzzz_install-harlequin.sh)" -eq 0 ]
}

@test "the harlequin script installs or upgrades harlequin with uv, Postgres adapter included" {
  uv_stub
  run env -i HOME="$H" PATH=/usr/bin:/bin sh "$REPO_ROOT/$HARLEQUIN_SCRIPT"
  [ "$status" -eq 0 ]
  grep -qxF 'uv tool install --upgrade harlequin[postgres]' "$CALLS"
}

@test "kubernetes installs kubectl and k9s on macOS, only when selected" {
  out=$(brews '["kubernetes"]')
  printf '%s\n' "$out" | grep -qxF 'brew "kubernetes-cli"'
  printf '%s\n' "$out" | grep -qxF 'brew "k9s"'
  [ "$(brews '[]' | grep -cE 'kubernetes-cli|k9s')" -eq 0 ]
}

@test "data installs duckdb on macOS, only when selected" {
  brews '["data"]' | grep -qxF 'brew "duckdb"'
  [ "$(brews '[]' | grep -c duckdb)" -eq 0 ]
}

@test "git_advanced installs lazygit on macOS" {
  brews '["git_advanced"]' | grep -qxF 'brew "lazygit"'
  [ "$(brews '[]' | grep -c lazygit)" -eq 0 ]
}

@test "on Linux, lazygit, k9s and duckdb come from their release archives, each with its module" {
  for pair in git_advanced:lazygit kubernetes:k9s data:duckdb; do
    m=${pair%%:*} bin=${pair#*:}
    linux_render "[\"$m\"]" .chezmoiexternal.toml.tmpl | grep -qxF "[\".local/bin/$bin\"]"
    [ "$(linux_render '[]' .chezmoiexternal.toml.tmpl | grep -cxF "[\".local/bin/$bin\"]")" -eq 0 ]
  done
}

# kubectl_stub VERSION — a kubectl that reports VERSION as its client version.
kubectl_stub() {
  printf '#!/bin/sh\necho "Client Version: %s"\n' "$1" > "$BIN/kubectl"
  chmod +x "$BIN/kubectl"
}

@test "on Linux, kubectl is downloaded only when it is not the stable release" {
  H="$BATS_TEST_TMPDIR/h"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$H" "$BIN"
  : > "$CALLS"
  # curl answers the stable-version lookup with v1.34.1; a download is logged
  # and writes a file to its -o target.
  cat > "$BIN/curl" << STUB
#!/bin/sh
echo "curl \$*" >> "$CALLS"
case "\$*" in
  *stable.txt*) printf 'v1.34.1' ;;
  *) out=""; while [ \$# -gt 0 ]; do [ "\$1" = -o ] && out="\$2"; shift; done; : > "\$out" ;;
esac
STUB
  chmod +x "$BIN/curl"
  kubectl_stub v1.34.1
  run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" sh "$REPO_ROOT/$KUBECTL_SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -c '/bin/linux/.*/kubectl' "$CALLS")" -eq 0 ]
  kubectl_stub v1.33.0
  run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" sh "$REPO_ROOT/$KUBECTL_SCRIPT"
  [ "$status" -eq 0 ]
  grep -q 'dl.k8s.io/release/v1.34.1/bin/linux/.*/kubectl' "$CALLS"
  [ -x "$H/.local/bin/kubectl" ]
}

@test "dotfiles_doctor checks each module's tools only when it is selected" {
  for pair in azure:az kubernetes:kubectl kubernetes:k9s data:duckdb data:harlequin; do
    m=${pair%%:*} tool=${pair#*:}
    render "[\"$m\"]" "$DOCTOR" | grep -q "__check_tool_with_configs $tool "
    [ "$(render '[]' "$DOCTOR" | grep -c "__check_tool_with_configs $tool ")" -eq 0 ]
  done
}

@test "containers adds the docker buildx plugin and lazydocker on macOS" {
  out=$(brews '["containers"]')
  printf '%s\n' "$out" | grep -qxF 'brew "docker-buildx"'
  printf '%s\n' "$out" | grep -qxF 'brew "lazydocker"'
  [[ "$(prompt_help containers)" == *buildx*lazydocker* ]]
}

@test "the buildx link script renders only with containers" {
  [ -n "$(render '["containers"]' "$BUILDX_TMPL" | tr -d '[:space:]')" ]
  [ -z "$(render '[]' "$BUILDX_TMPL" | tr -d '[:space:]')" ]
}

@test "the buildx link script puts the brew plugin where the docker CLI looks" {
  H="$BATS_TEST_TMPDIR/h"
  BIN="$BATS_TEST_TMPDIR/bin"
  P="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$H" "$BIN" "$P/opt/docker-buildx/bin"
  : > "$P/opt/docker-buildx/bin/docker-buildx"
  printf '#!/bin/sh\n[ "$1" = --prefix ] && echo "%s"\n' "$P" > "$BIN/brew"
  chmod +x "$BIN/brew"
  render '["containers"]' "$BUILDX_TMPL" > "$BATS_TEST_TMPDIR/link.sh"
  for _ in 1 2; do
    run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" sh "$BATS_TEST_TMPDIR/link.sh"
    [ "$status" -eq 0 ]
    [ "$(readlink "$H/.docker/cli-plugins/docker-buildx")" = "$P/opt/docker-buildx/bin/docker-buildx" ]
  done
}

@test "the README names the new tools" {
  grep -qE '^\| `git_advanced` \|.*lazygit' "$REPO_ROOT/README.md"
  grep -qE '^\| `kubernetes` \|' "$REPO_ROOT/README.md"
  grep -qE '^\| `data` \|' "$REPO_ROOT/README.md"
  grep -qE '^\| `azure` \|' "$REPO_ROOT/README.md"
}
