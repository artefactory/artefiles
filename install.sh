#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

dry_run=false
destination=""

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
    # The value reaches git as an argument: refuse anything git could read as an option.
    case "$ARTEFILES_VERSION" in
      -* | *[!A-Za-z0-9._/-]*)
        echo "ARTEFILES_VERSION='${ARTEFILES_VERSION}' is not a valid tag or branch name." >&2
        return 1
        ;;
    esac
    printf '%s\n' "$ARTEFILES_VERSION"
    return 0
  fi
  # A dry run never calls GitHub.
  [ "$dry_run" = "true" ] && return 0
  if tag="$(gh release view --repo artefactory/artefiles --json tagName --jq .tagName 2> /dev/null)" && [ -n "$tag" ]; then
    printf '%s\n' "$tag"
  else
    echo "Could not find the latest release; installing the default branch instead." >&2
  fi
}

# Clone the repo at $ref (the default branch when empty) into $1.
clone_repo() {
  if [ -n "$ref" ]; then
    gh repo clone artefactory/artefiles "$1" -- --branch "$ref"
  else
    gh repo clone artefactory/artefiles "$1"
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
    echo "${ref} is not a tag or branch of artefactory/artefiles." >&2
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
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
    latest_version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

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

    download_url="https://github.com/cli/cli/releases/download/v${latest_version}/gh_${latest_version}_${os}_${arch_name}.tar.gz"
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

    # Default required scopes for full functionality
    SCOPES="repo,read:org,gist"

    # Attempt browser-based authentication with SSH for git operations
    # This is preferred as it's more secure and supports 2FA
    if gh auth login \
      --git-protocol ssh \
      --scopes "${SCOPES}" \
      --web \
      ||
      # Fallback to HTTPS if SSH fails
      gh auth login \
        --git-protocol https \
        --scopes "${SCOPES}" \
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

# GitHub CLI setup (skipped in dry-run)
if [ "$dry_run" = "false" ]; then
  install_github_cli
  ensure_github_auth
fi

# Install chezmoi if not already installed (skipped in dry-run)
if [ "$dry_run" = "false" ]; then
  if ! chezmoi="$(command -v chezmoi)"; then
    bin_dir="$(set_bin_dir)"
    chezmoi="${bin_dir}/chezmoi"
    echo "Installing chezmoi to '${chezmoi}'" >&2
    if command -v curl > /dev/null; then
      chezmoi_install_script="$(curl -fsSL https://chezmoi.io/get)"
    elif command -v wget > /dev/null; then
      chezmoi_install_script="$(wget -qO- https://chezmoi.io/get)"
    else
      echo "To install chezmoi, you must have curl or wget installed." >&2
      exit 1
    fi
    sh -c "${chezmoi_install_script}" -- -b "${bin_dir}"
    unset chezmoi_install_script bin_dir
  fi
else
  chezmoi="chezmoi"
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

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
chezmoi_config="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi/chezmoi.toml"
if [ "$dry_run" = "false" ] && [ "$interactive" = "true" ] && [ ! -f "$chezmoi_config" ]; then
  # The Quick Start has no checkout: clone with gh so the checklist is available.
  if [ ! -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
    clone_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/chezmoi"
    if [ -f "${clone_dir}/.chezmoi.toml.tmpl" ]; then
      # A clone from an earlier install is reused; bring it to the requested version.
      [ -z "$ref" ] || checkout_ref "$clone_dir" >&2 || exit 1
      script_dir="$clone_dir"
    elif [ ! -e "$clone_dir" ] && clone_repo "$clone_dir" >&2; then
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
        printf '[data]\n  modulesVersion = %s\n  modules = %s\n' "$version" "$selection" > "$chezmoi_config"
        ;;
      1)
        echo "Installation cancelled." >&2
        exit 1
        ;;
    esac
  fi
fi

# Run as `sh -c "$(curl ...)"` there is no script file: $0 is "sh" and script_dir
# is the directory holding sh, not a checkout. Only a checkout may be the
# chezmoi source; otherwise let chezmoi clone the repo.
if [ -f "${script_dir}/.chezmoi.toml.tmpl" ]; then
  set -- init --apply "--source=${script_dir}"
else
  set -- init --apply
  [ -z "$ref" ] || set -- "$@" "--branch=${ref}"
  set -- "$@" artefactory/artefiles
fi
[ -n "${destination}" ] && set -- "$@" "--destination=${destination}"
[ "$dry_run" = "true" ] && set -- "$@" "--dry-run"

echo "Running 'chezmoi $*'" >&2
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

"$chezmoi" "$@"

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
