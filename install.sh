#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

# Where artefiles and the tools it bootstraps come from.
REPO="artefactory/artefiles"
GITHUB_HOME="https://github.com"
HOMEBREW_INSTALLER="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
CHEZMOI_INSTALLER="https://chezmoi.io/get"
GH_LATEST_RELEASE="https://api.github.com/repos/cli/cli/releases/latest"
GH_DOWNLOADS="https://github.com/cli/cli/releases/download"
# Scopes the GitHub login asks for; gh and git need them on private repositories.
GH_SCOPES="repo,read:org,gist"
# Seconds the network check waits for each answer.
NETWORK_TIMEOUT=10

dry_run=false
destination=""
restore=""

# Parse --dry-run / --destination before any other work
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --destination)
      destination="${2:?--destination requires a value}"
      shift 2
      ;;
    --destination=*)
      destination="${1#*=}"
      shift
      ;;
    --restore)
      restore="${2:?--restore requires a backup folder}"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

# The tag or branch to install: ARTEFILES_VERSION when set, else the latest GitHub
# release, else (no release, or gh cannot reach it) the default branch with a
# warning. An explicit value never falls back, so a typo fails instead of
# installing something else. Prints nothing when the default branch is meant.
resolve_ref() {
  if [ -n "${ARTEFILES_VERSION:-}" ]; then
    # The preflight has already refused a value git could read as an option.
    printf '%s\n' "$ARTEFILES_VERSION"
    return 0
  fi
  # A dry run never calls GitHub.
  [ "$dry_run" = "true" ] && return 0
  if tag="$(gh release view --repo "$REPO" --json tagName --jq .tagName 2> /dev/null)" && [ -n "$tag" ]; then
    printf '%s\n' "$tag"
  else
    echo "Could not find the latest release; installing the default branch instead." >&2
  fi
}

# Clone the repo at $ref (the default branch when empty) into $1.
clone_repo() {
  if [ -n "$ref" ]; then
    gh repo clone "$REPO" "$1" -- --branch "$ref"
  else
    gh repo clone "$REPO" "$1"
  fi
}

# Move an existing clone in $1 to $ref, so a re-run with ARTEFILES_VERSION installs
# that version and not whatever the earlier install left checked out. A tag wins
# over a branch of the same name and is checked out detached. A branch is checked
# out as a local branch tracking origin, so `chezmoi update` can pull it later; an
# existing local branch is only fast-forwarded, never reset. Fails, naming the
# clone, when $ref does not exist, the local branch has commits of its own, or the
# working tree has changes that block the checkout.
checkout_ref() {
  # A tag the clone already has and is on needs no fetch: a rerun at the same
  # version changes nothing. A branch is fetched first, since its tip is only
  # known after the fetch.
  if here="$(git -C "$1" rev-parse --verify --quiet HEAD)" \
    && [ "$(git -C "$1" rev-parse --verify --quiet "refs/tags/${ref}^{commit}")" = "$here" ]; then
    echo "already at ${ref}" >&2
    return 0
  fi
  git -C "$1" fetch --quiet --force --tags origin '+refs/heads/*:refs/remotes/origin/*' || {
    echo "Could not fetch ${ref} into ${1}." >&2
    return 1
  }
  if target="$(git -C "$1" rev-parse --verify --quiet "refs/tags/${ref}^{commit}")"; then
    set -- "$1" --detach "$target"
  elif git -C "$1" rev-parse --verify --quiet "refs/remotes/origin/${ref}^{commit}" > /dev/null; then
    if ! git -C "$1" rev-parse --verify --quiet "refs/heads/${ref}" > /dev/null; then
      set -- "$1" -b "$ref" --track "origin/${ref}"
    elif git -C "$1" merge-base --is-ancestor "refs/heads/${ref}" "refs/remotes/origin/${ref}"; then
      set -- "$1" "$ref"
    else
      echo "The local branch ${ref} in ${1} has commits of its own; push or remove them, or remove the folder." >&2
      return 1
    fi
  else
    echo "${ref} is not a tag or branch of ${REPO}." >&2
    return 1
  fi
  dir="$1"
  shift
  git -C "$dir" checkout --quiet "$@" || {
    echo "Could not check out ${ref} in ${dir}; commit or stash its changes, or remove the folder." >&2
    return 1
  }
  [ "$1" = "$ref" ] || return 0
  git -C "$dir" merge --quiet --ff-only "origin/${ref}" || {
    echo "Could not move ${ref} in ${dir} to origin/${ref}; commit or stash its changes, or remove the folder." >&2
    return 1
  }
}

# Set bin directory based on OS
set_bin_dir() {
  if [ "$(uname)" = "Darwin" ]; then
    # Use Homebrew's bin directory on macOS if brew is installed
    if command -v brew > /dev/null 2>&1; then
      bin_dir="$(brew --prefix)/bin"
    else
      # Fallback to local bin if brew is not installed
      bin_dir="${HOME}/.local/bin"
    fi
  else
    # Use local bin directory on Linux
    bin_dir="${HOME}/.local/bin"
  fi
  mkdir -p "${bin_dir}"
  printf '%s\n' "${bin_dir}"
}

# Install Homebrew on macOS if not already present; idempotent
install_homebrew() {
  [ "$(uname)" = "Darwin" ] || return 0
  if command -v brew > /dev/null 2>&1; then
    echo "Homebrew already installed" >&2
    return 0
  fi
  echo "Installing Homebrew..." >&2
  [ "$dry_run" = "true" ] && return 0
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALLER")"
}

# Install GitHub CLI first if not already installed
install_github_cli() {
  if ! command -v gh > /dev/null 2>&1; then
    echo "Installing GitHub CLI..." >&2
    bin_dir="$(set_bin_dir)"

    # On macOS, prefer Homebrew installation
    if [ "$(uname)" = "Darwin" ] && command -v brew > /dev/null 2>&1; then
      echo "Installing GitHub CLI via Homebrew..." >&2
      brew install gh
      return
    fi

    # Get latest version
    latest_version=$(curl -s "$GH_LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

    # Download and install for current architecture
    arch=$(uname -m)
    case "${arch}" in
      x86_64) arch_name="amd64" ;;
      aarch64 | arm64) arch_name="arm64" ;;
      *)
        echo "Unsupported architecture: ${arch}" >&2
        exit 1
        ;;
    esac

    # Set OS-specific download URL
    os="linux"
    if [ "$(uname)" = "Darwin" ]; then
      os="macOS"
    fi

    download_url="${GH_DOWNLOADS}/v${latest_version}/gh_${latest_version}_${os}_${arch_name}.tar.gz"
    tmp_dir=$(mktemp -d)
    curl -sL "${download_url}" | tar xz -C "${tmp_dir}"
    cp "${tmp_dir}"/gh_*/bin/gh "${bin_dir}/"
    rm -rf "${tmp_dir}"
    echo "GitHub CLI installed successfully" >&2
  else
    echo "GitHub CLI already installed" >&2
  fi
}

# Ensure GitHub CLI authentication, exit if authentication fails
ensure_github_auth() {
  # Check if already authenticated
  if gh auth status > /dev/null 2>&1; then
    echo "GitHub CLI already authenticated" >&2
    return 0
  fi

  echo "GitHub CLI authentication required" >&2

  # Check if we have a token in environment variables
  if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Using token from environment variables" >&2
    # Verify token works
    temp_error_file=$(mktemp)
    if ! gh auth status 2> "$temp_error_file" > /dev/null; then
      err_msg=$(cat "$temp_error_file" 2> /dev/null || echo "Unknown authentication error")
      echo "ERROR: Invalid GitHub token provided in environment variables" >&2
      echo "ERROR: Details: $err_msg" >&2
      rm -f "$temp_error_file"
      exit 1
    fi
    rm -f "$temp_error_file"
    return 0
  fi

  # Check if we're in an interactive environment
  if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
    echo "Starting interactive GitHub authentication..." >&2

    # Attempt browser-based authentication with SSH for git operations
    # This is preferred as it's more secure and supports 2FA
    if gh auth login \
      --git-protocol ssh \
      --scopes "$GH_SCOPES" \
      --web \
      ||
      # Fallback to HTTPS if SSH fails
      gh auth login \
        --git-protocol https \
        --scopes "$GH_SCOPES" \
        --web; then
      echo "GitHub CLI authentication successful" >&2
      return 0
    fi
  fi

  echo "ERROR: GitHub CLI authentication required to enable full functionality." >&2
  echo "For interactive environments, run this script in a terminal." >&2
  echo "For non-interactive environments, set GH_TOKEN environment variable." >&2
  exit 1
}

# True when someone can answer prompts: a terminal on stdin, stdout and stderr,
# and neither CI nor Codespaces, which win even with a terminal attached.
# ARTEFILES_SELECT_TTY only exists so tests can stand in for the terminal.
interactive=false
if [ -n "${CI:-}" ] || [ -n "${CODESPACES:-}" ]; then
  interactive=false
elif [ -n "${ARTEFILES_SELECT_TTY:-}" ]; then
  interactive=true
elif [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
  interactive=true
fi

# install.sh --restore FOLDER: undo an install from the backup folder the
# install printed. Lists what it will do and asks first; without a terminal it
# changes nothing. chezmoi purge deletes the source folder too, so it only runs
# when the source is the clone the install made; a checkout of the user's own
# is kept and only chezmoi's config and state are removed.
restore_backup() {
  dest="${destination:-$HOME}"
  if [ ! -f "${restore}/created.txt" ]; then
    echo "${restore} is not an artefiles backup folder (it has no created.txt); nothing was changed." >&2
    exit 1
  fi
  config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi"
  clone_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/chezmoi"
  source_dir="$(chezmoi source-path 2> /dev/null || :)"
  echo "Restoring the backup in ${restore} into ${dest}:" >&2
  echo "  copy back:" >&2
  (cd "${restore}/files" 2> /dev/null && find . ! -type d | sed 's|^\./|    |') >&2
  echo "  delete what the install created:" >&2
  sed 's|^|    |' "${restore}/created.txt" >&2
  if [ -n "$source_dir" ] && [ "$source_dir" = "$clone_dir" ]; then
    echo "  remove chezmoi's config, state and its clone of artefiles (chezmoi purge --force)" >&2
  else
    echo "  remove chezmoi's config and state in ${config_dir}${source_dir:+; ${source_dir} is kept}" >&2
  fi
  echo "Software the install added (Homebrew packages, fish, the tools in ~/.local) is not removed; CHEATSHEET.md lists how to remove it." >&2
  if [ "$interactive" != "true" ]; then
    echo "--restore asks before changing anything and needs a terminal; nothing was changed." >&2
    exit 1
  fi
  printf 'Restore? [y/N] ' >&2
  answer=""
  read -r answer < "${ARTEFILES_TTY:-/dev/tty}" || :
  case "$answer" in
    y | Y | yes | YES) ;;
    *)
      echo "Nothing was changed." >&2
      exit 1
      ;;
  esac
  [ ! -d "${restore}/files" ] || cp -Rp "${restore}/files/." "${dest}/"
  # Deepest paths first, so a folder is empty by the time it is reached; a
  # folder that holds anything else stays.
  sort -r "${restore}/created.txt" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -d "${dest}/${path}" ] && [ ! -L "${dest}/${path}" ]; then
      rmdir "${dest}/${path}" 2> /dev/null || :
    else
      rm -f "${dest}/${path}"
    fi
  done
  if [ -n "$source_dir" ] && [ "$source_dir" = "$clone_dir" ]; then
    chezmoi purge --force
  else
    rm -rf "$config_dir"
  fi
  echo "Restored. Open a new terminal." >&2
  exit 0
}
[ -z "$restore" ] || restore_backup

# Homebrew's installer and some casks need sudo. With no ticket each asks on its
# own, often behind scrolling output so the install looks stuck. Ask once, up
# front, then refresh the ticket until the install ends. Only on macOS, at a
# terminal, and never in dry-run: elsewhere nothing before the final shell offer
# uses sudo.
sudo_keepalive_pid=""
stop_sudo_keepalive() {
  if [ -n "$sudo_keepalive_pid" ]; then
    kill "$sudo_keepalive_pid" 2> /dev/null || :
    sudo_keepalive_pid=""
  fi
}
start_sudo_keepalive() {
  [ "$dry_run" = "false" ] && [ "$interactive" = "true" ] || return 0
  [ "$(uname)" = "Darwin" ] && command -v sudo > /dev/null 2>&1 || return 0
  echo "Some steps need administrator rights: enter your password once if asked." >&2
  if ! sudo -v; then
    if ! command -v brew > /dev/null 2>&1; then
      cat >&2 << 'MSG'
Homebrew needs administrator rights to install, and sudo was refused. Your
account may not be allowed to use sudo (a managed Mac can remove it). Ask your
IT team to restore administrator rights, then run the install again.
MSG
      exit 1
    fi
    cat >&2 << 'MSG'
Your account may not be allowed to use sudo (a managed Mac can remove it).
Homebrew and casks such as ghostty will fail without it. Ask your IT team to
restore administrator rights, then run the install again. Continuing anyway.
MSG
    return 0
  fi
  # $$ is the install's pid even in the subshell, so the loop ends with it.
  (
    while kill -0 "$$" 2> /dev/null; do
      sleep "${ARTEFILES_SUDO_REFRESH:-50}"
      sudo -n -v 2> /dev/null || exit 0
    done
  ) &
  sudo_keepalive_pid=$!
}
trap stop_sudo_keepalive EXIT
trap 'stop_sudo_keepalive; exit 130' INT
trap 'stop_sudo_keepalive; exit 143' TERM
trap 'stop_sudo_keepalive; exit 129' HUP

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

# The module checklist runs only at a terminal, outside a dry run, and never over
# an existing chezmoi config (see below).
chezmoi_config="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi/chezmoi.toml"
checklist=false
if [ "$dry_run" = "false" ] && [ "$interactive" = "true" ] && [ ! -f "$chezmoi_config" ]; then
  checklist=true
fi

# Preflight: every check the install needs, run before anything is installed or
# written. The checks only read; every failure is collected and printed
# together, so one run lists everything to fix.
preflight_failures=""
fail_check() {
  preflight_failures="${preflight_failures}  - $1
"
}
stop_on_failures() {
  [ -n "$preflight_failures" ] || return 0
  printf 'artefiles cannot be installed yet:\n%sFix these, then run the install again.\n' "$preflight_failures" >&2
  exit 1
}

# True when $1 answers over HTTPS.
reachable() {
  curl -fsSI --max-time "$NETWORK_TIMEOUT" -o /dev/null "$1"
}

# The network probe needs someone at a terminal and never runs in a dry run.
preflight() {
  os="$(uname)"
  case "$os" in
    Darwin | Linux) ;;
    *) fail_check "${os} is not supported: artefiles installs on macOS and Linux." ;;
  esac
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64 | aarch64 | arm64) ;;
    *) fail_check "${arch} processors are not supported: artefiles needs x86_64 or arm64." ;;
  esac

  has_curl=true
  if ! command -v curl > /dev/null 2>&1; then
    has_curl=false
    fail_check "artefiles needs curl to download its tools: install curl."
  fi

  [ -w "$HOME" ] || fail_check "cannot write to ${HOME}: the install writes your configuration there."
  if [ -e "${HOME}/.local/bin" ] && [ ! -w "${HOME}/.local/bin" ]; then
    fail_check "cannot write to ${HOME}/.local/bin: the install puts tools there."
  fi

  # The value reaches git as an argument: refuse anything git could read as an
  # option. A checkout installs itself and ignores the value.
  if [ -n "${ARTEFILES_VERSION:-}" ] && [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
    case "$ARTEFILES_VERSION" in
      -* | *[!A-Za-z0-9._/-]*)
        fail_check "ARTEFILES_VERSION='${ARTEFILES_VERSION}' is not a valid tag or branch name."
        ;;
    esac
  fi

  # Only the checklist path runs git itself (gh repo clone, checkout_ref);
  # chezmoi falls back to its own git.
  if [ "$checklist" = "true" ] && [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ] && ! command -v git > /dev/null 2>&1; then
    fail_check "artefiles needs git to fetch its files: install git."
  fi

  if [ "$has_curl" = "true" ] && [ "$dry_run" = "false" ] && [ "$interactive" = "true" ]; then
    reachable "$GITHUB_HOME" || fail_check "cannot reach ${GITHUB_HOME}: check the network connection or proxy."
    if [ "$os" = "Darwin" ] && ! command -v brew > /dev/null 2>&1; then
      reachable "$HOMEBREW_INSTALLER" \
        || fail_check "cannot reach the Homebrew installer on https://raw.githubusercontent.com: check the network connection or proxy."
    fi
  fi
}
preflight
stop_on_failures

# Install Homebrew first on macOS so chezmoi scripts inherit brew on PATH
start_sudo_keepalive
install_homebrew
if [ "$(uname)" = "Darwin" ]; then
  # A fresh `install_homebrew` writes brew to /opt/homebrew/bin (Apple
  # Silicon) or /usr/local/bin (Intel) but doesn't update the current
  # shell's PATH. Probe the canonical install paths so `brew shellenv`
  # below succeeds even on a cold install — without this, the eval is
  # silently skipped and chezmoi inherits a brew-less PATH.
  if ! command -v brew > /dev/null 2>&1; then
    if [ -x "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  if command -v brew > /dev/null 2>&1; then
    eval "$(brew shellenv)"
  fi
fi

# The install itself needs none of the login's scopes; they serve gh and git on
# private repositories later, so a missing one only warns. gh lists scopes only
# for classic and OAuth tokens, so fine-grained and CI job tokens are not checked;
# with several accounts the first listed one is read.
warn_missing_scopes() {
  scopes="$(gh auth status 2>&1 | sed -n "s/.*Token scopes: //p" | head -n 1)"
  [ -n "$scopes" ] || return 0
  missing=""
  case "$scopes" in *"'repo'"*) ;; *) missing="${missing} repo" ;; esac
  case "$scopes" in *"'read:org'"* | *"'write:org'"* | *"'admin:org'"*) ;; *) missing="${missing} read:org" ;; esac
  case "$scopes" in *"'gist'"*) ;; *) missing="${missing} gist" ;; esac
  [ -z "$missing" ] || echo "Warning: the GitHub login lacks the scopes${missing}; gh and git may fail on private repositories. To add them: gh auth refresh --scopes ${GH_SCOPES}" >&2
}

# GitHub CLI setup (skipped in dry-run)
if [ "$dry_run" = "false" ]; then
  install_github_cli
  ensure_github_auth
  warn_missing_scopes
fi

# Install chezmoi if not already installed (skipped in dry-run)
if [ "$dry_run" = "false" ]; then
  if ! chezmoi="$(command -v chezmoi)"; then
    bin_dir="$(set_bin_dir)"
    chezmoi="${bin_dir}/chezmoi"
    echo "Installing chezmoi to '${chezmoi}'" >&2
    chezmoi_install_script="$(curl -fsSL "$CHEZMOI_INSTALLER")"
    sh -c "${chezmoi_install_script}" -- -b "${bin_dir}"
    unset chezmoi_install_script bin_dir
  fi
else
  chezmoi="chezmoi"
fi

# A checkout installs itself; only the Quick Start and the manual path fetch a version.
ref=""
if [ -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
  [ -z "${ARTEFILES_VERSION:-}" ] || echo "Installing from ${script_dir}; ARTEFILES_VERSION is ignored." >&2
else
  ref="$(resolve_ref)"
  [ -z "$ref" ] || echo "Installing artefiles ${ref}" >&2
fi

# Module checklist: chezmoi's own prompt does not show what is selected, so ask
# here and store the answer; chezmoi init then reuses it without prompting. Only
# at a terminal, never in CI, and never over an existing chezmoi config.
if [ "$checklist" = "true" ]; then
  # The Quick Start has no checkout: clone with gh so the checklist is available.
  if [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
    clone_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/chezmoi"
    if [ -f "${clone_dir}/.chezmoi.toml.tmpl" ]; then
      # A clone from an earlier install is reused; bring it to the requested version.
      [ -z "$ref" ] || checkout_ref "$clone_dir" >&2 || exit 1
      script_dir="$clone_dir"
    elif [ ! -e "$clone_dir" ]; then
      clone_repo "$clone_dir" >&2 || {
        echo "Could not clone ${REPO} into ${clone_dir}." >&2
        exit 1
      }
      script_dir="$clone_dir"
    fi
  fi
  if [ -f "${script_dir}/select-modules.sh" ]; then
    status=0
    selection="$(sh "${script_dir}/select-modules.sh")" || status=$?
    case "$status" in
      0)
        mkdir -p "$(dirname "$chezmoi_config")"
        # The version marks the list as made for the current module set (see .chezmoi.toml.tmpl).
        version="$(cat "${script_dir}/.chezmoitemplates/modulesVersion")"
        # Every module was shown, so an update offers only those added later.
        # shellcheck disable=SC2016 # the pattern matches a literal `$choices`
        offered="[$(sed -nE 's/^# \[\[ \$choices = append \$choices "([a-z_]+) \|.*/"\1"/p' "${script_dir}/.chezmoi.toml.tmpl" | paste -sd, -)]"
        printf '[data]\n  modulesVersion = %s\n  modules = %s\n  modulesOffered = %s\n' "$version" "$selection" "$offered" > "$chezmoi_config"
        ;;
      1)
        echo "Installation cancelled." >&2
        exit 1
        ;;
    esac
  fi
fi

# A rerun over an existing config skips the checklist above, but chezmoi init
# ignores --branch once the source is cloned and re-renders the config from the
# clone as it is. So a version named with ARTEFILES_VERSION moves the existing
# clone first.
if [ "$checklist" = "false" ] && [ "$dry_run" = "false" ] && [ -n "${ARTEFILES_VERSION:-}" ] \
  && [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
  existing="$("$chezmoi" source-path 2> /dev/null || echo "${XDG_DATA_HOME:-${HOME}/.local/share}/chezmoi")"
  if [ -d "${existing}/.git" ]; then
    checkout_ref "$existing" >&2 || exit 1
  fi
fi

# Run as `sh -c "$(curl ...)"` there is no script file: $0 is "sh" and script_dir
# is the directory holding sh, not a checkout. Only a checkout may be the
# chezmoi source; otherwise let chezmoi clone the repo.
# chezmoi init writes the config first, so its template checks run before any file
# is written; chezmoi apply then writes the files. The source directory is kept
# in the config; the destination is not, so both steps get it.
if [ -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
  set -- init "--source=${script_dir}"
else
  set -- init
  [ -z "$ref" ] || set -- "$@" "--branch=${ref}"
  set -- "$@" "$REPO"
fi
apply_destination=""
if [ -n "${destination}" ]; then
  set -- "$@" "--destination=${destination}"
  apply_destination="--destination=${destination}"
fi
# chezmoi's prompts need a terminal and fail without one; there, every prompt
# takes its default (the GitHub email, the default modules).
[ -t 0 ] || set -- "$@" --promptDefaults

# Before chezmoi init: everything it is given must be usable. A version that a
# clone or checkout_ref has not already found must exist on GitHub, since chezmoi
# would otherwise fail on its own clone. Skipped in a dry run, which installs
# nothing to check.
preflight_init() {
  [ "$dry_run" = "false" ] || return 0
  "$chezmoi" --version > /dev/null 2>&1 || fail_check "chezmoi does not run (${chezmoi}): reinstall it or remove it so the install fetches it."
  if [ -n "$ref" ] && [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
    gh api "repos/${REPO}/commits/${ref}" --silent > /dev/null 2>&1 \
      || fail_check "${ref} is not a tag or branch of ${REPO}."
  fi
  if [ -n "$destination" ] && [ -e "$destination" ] && [ ! -w "$destination" ]; then
    fail_check "cannot write to ${destination}: the files are written there."
  fi
  # chezmoi apply does not create a missing destination, so install.sh does,
  # inside the nearest folder that exists.
  if [ -n "$destination" ] && [ ! -e "$destination" ]; then
    parent="$destination"
    while [ ! -e "$parent" ]; do parent="$(dirname "$parent")"; done
    [ -w "$parent" ] || fail_check "cannot create ${destination}: ${parent} cannot be written."
  fi
}
preflight_init
stop_on_failures

echo "Running 'chezmoi $*'" >&2
echo "Running 'chezmoi apply --keep-going${apply_destination:+ }${apply_destination}'" >&2
[ "$dry_run" = "true" ] && exit 0

# chezmoi looks up the latest GitHub releases through the GitHub API, which
# allows 60 requests per hour per IP address without a token, and an office
# often shares one address. gh is already logged in, so lend its token to chezmoi
# unless one is set; it lives only in this process's environment.
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GITHUB_ACCESS_TOKEN:-}" ] && [ -z "${CHEZMOI_GITHUB_ACCESS_TOKEN:-}" ]; then
  gh_token="$(gh auth token 2> /dev/null || true)"
  if [ -n "$gh_token" ]; then
    GITHUB_TOKEN="$gh_token"
    export GITHUB_TOKEN
  fi
  unset gh_token
fi

# A first apply overwrites the files the user already has without asking. Before
# it, every existing file it would change or delete is copied into a dated
# folder, next to created.txt (what it would create) and chezmoi's state, so the
# install can be undone. Scripts and externals install software, which a copy
# cannot restore, so they are left out. Prints the folder, or nothing when the
# apply would change nothing (a rerun of an installed version).
backup_before_apply() {
  dest="${destination:-$HOME}"
  changes="$("$chezmoi" status --exclude=scripts,externals ${apply_destination:+"$apply_destination"})" || {
    echo "Could not list the files the install would change, so nothing was written." >&2
    return 1
  }
  [ -n "$changes" ] || return 0
  backup="${XDG_STATE_HOME:-${HOME}/.local/state}/artefiles/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "${backup}/files"
  : > "${backup}/created.txt"
  # `chezmoi status` prints two status columns, a space and the path relative to
  # the destination; the second column is what the apply would do.
  printf '%s\n' "$changes" | while IFS= read -r line; do
    action="$(printf '%s' "$line" | cut -c2)"
    path="$(printf '%s' "$line" | cut -c4-)"
    case "$action" in
      A) printf '%s\n' "$path" >> "${backup}/created.txt" ;;
      M | D)
        if [ -f "${dest}/${path}" ] || [ -L "${dest}/${path}" ]; then
          mkdir -p "$(dirname "${backup}/files/${path}")"
          cp -Pp "${dest}/${path}" "${backup}/files/${path}"
        fi
        ;;
    esac
  done
  "$chezmoi" state dump > "${backup}/state.json" 2> /dev/null || :
  printf '%s\n' "$backup"
}

# How to undo the install from the backup folder $1.
print_restore_steps() {
  dest="${destination:-$HOME}"
  cat >&2 << MSG
Your earlier files are saved in ${1}. To undo the install:
  1. copy them back: cp -Rp "${1}/files/." "${dest}/"
  2. delete the files the install created, listed in ${1}/created.txt,
     and those folders once they are empty
  3. remove chezmoi's config, state and source: chezmoi purge --force
     (it deletes $("$chezmoi" source-path 2> /dev/null || echo "the source folder") too)
Or run: sh "$("$chezmoi" source-path 2> /dev/null || echo .)/install.sh" --restore "${1}"
Software the install added (Homebrew packages, fish, the tools in ~/.local) is
not removed by these steps; CHEATSHEET.md lists how to remove it.
MSG
}

[ -z "$destination" ] || mkdir -p "$destination"
"$chezmoi" "$@"
backup="$(backup_before_apply)" || exit 1
# --keep-going runs every step after a failure. chezmoi records a script only
# once it exits 0, so the next apply runs the failed ones and skips the rest.
# Its errors still reach the terminal; a copy is kept to name the failed steps.
apply_log="$(mktemp)"
{
  {
    status=0
    "$chezmoi" apply --keep-going ${apply_destination:+"$apply_destination"} || status=$?
    echo "$status" > "${apply_log}.status"
  } 2>&1 1>&3 3>&- | tee "$apply_log" >&2
} 3>&1
apply_status="$(cat "${apply_log}.status")"
[ -z "$backup" ] || print_restore_steps "$backup"
if [ "$apply_status" -ne 0 ]; then
  # chezmoi reports a failed script as "chezmoi: <script>: exit status <n>".
  failed="$(sed -n 's/^chezmoi: \(.*\): exit status [0-9]*$/\1/p' "$apply_log")"
  rm -f "$apply_log" "${apply_log}.status"
  if [ -n "$failed" ]; then
    echo "$(printf '%s\n' "$failed" | wc -l | tr -d ' ') install step(s) failed:" >&2
    printf '%s\n' "$failed" | sed 's/^/  - /' >&2
    echo "Every other step finished and is recorded. To retry only the failed ones: chezmoi apply --keep-going" >&2
  else
    echo "The install stopped on the error above. To retry: chezmoi apply --keep-going" >&2
  fi
  exit "$apply_status"
fi
rm -f "$apply_log" "${apply_log}.status"

# Last step, only reached once chezmoi succeeded (set -e): the login shell
# change needs sudo and an attentive user, so nothing may depend on it or run
# alongside it.
if source_dir="$("$chezmoi" source-path 2> /dev/null)" && [ -f "${source_dir}/offer-default-shell.sh" ]; then
  sh "${source_dir}/offer-default-shell.sh" || true
fi

# Also last-step and optional: starring is only ever offered, never assumed.
if [ -n "${source_dir:-}" ] && [ -f "${source_dir}/offer-star.sh" ]; then
  sh "${source_dir}/offer-star.sh" || true
fi

# An @artefact.com user whose GitHub account is not yet in the artefactory
# organisation finds out when a clone fails, so say it once, as the last message
# of a successful install. It only reads: when the membership cannot be read
# (no gh, no network, a 401 or 403), nothing is shown.
warn_artefactory_membership() {
  [ "$interactive" = "true" ] || return 0
  email="$("$chezmoi" execute-template '{{ .email }}' 2> /dev/null)" || return 0
  case "$email" in *@artefact.com) ;; *) return 0 ;; esac
  command -v gh > /dev/null 2>&1 || return 0
  # -i prints the HTTP status line first; gh exits non-zero on a 404.
  answer="$(gh api -i user/memberships/orgs/artefactory 2> /dev/null || :)"
  code="$(printf '%s\n' "$answer" | head -n 1 | awk '{print $2}')"
  case "$code" in
    200)
      if printf '%s\n' "$answer" | grep -q '"state": *"pending"'; then
        echo "Warning: an invitation to the artefactory organisation is waiting for your GitHub account; accept it at https://github.com/orgs/artefactory/invitation" >&2
      fi
      ;;
    404)
      echo "Warning: your GitHub account is not yet in the artefactory organisation. Some repositories will not be reachable until you join. Ask your team how to join." >&2
      ;;
  esac
  return 0
}
warn_artefactory_membership
