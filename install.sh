#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

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
  echo "${bin_dir}"
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

# Install and authenticate GitHub CLI before anything else
install_github_cli
ensure_github_auth

# Install chezmoi if not already installed
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

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

set -- init --apply --source="${script_dir}"

echo "Running 'chezmoi $*'" >&2
# exec: replace current process with chezmoi
exec "$chezmoi" "$@"
