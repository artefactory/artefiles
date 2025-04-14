#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

# Install GitHub CLI first if not already installed
install_github_cli() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Installing GitHub CLI..." >&2
    bin_dir="${HOME}/.local/bin"
    mkdir -p "${bin_dir}"
    
    # Get latest version
    latest_version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    # Download and install for current architecture
    arch=$(uname -m)
    case "${arch}" in
      x86_64) arch_name="amd64" ;;
      aarch64|arm64) arch_name="arm64" ;;
      *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;;
    esac
    
    download_url="https://github.com/cli/cli/releases/download/v${latest_version}/gh_${latest_version}_linux_${arch_name}.tar.gz"
    tmp_dir=$(mktemp -d)
    curl -sL "${download_url}" | tar xz -C "${tmp_dir}"
    cp "${tmp_dir}"/gh_*/bin/gh "${bin_dir}/"
    rm -rf "${tmp_dir}"
    echo "GitHub CLI installed successfully" >&2
  else
    echo "GitHub CLI already installed" >&2
  fi
}

# Try to authenticate with GitHub CLI if we're in an interactive environment
try_github_auth() {
  # Check if we're in an interactive environment
  if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
    # Check if already authenticated
    if ! gh auth status >/dev/null 2>&1; then
      echo "Attempting GitHub CLI authentication..." >&2
      
      # Check if we have a token in environment variables
      if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "Using token from environment variables" >&2
        return 0
      fi
      
      # Default required scopes for full functionality
      SCOPES="repo,read:org,gist"
      
      # Attempt browser-based authentication with SSH for git operations
      # This is preferred as it's more secure and supports 2FA
      if gh auth login \
        --git-protocol ssh \
        --scopes "${SCOPES}" \
        --web || \
        # Fallback to HTTPS if SSH fails
        gh auth login \
        --git-protocol https \
        --scopes "${SCOPES}" \
        --web; then
        echo "GitHub CLI authentication successful" >&2
      else
        echo "GitHub CLI authentication failed. You can run 'gh auth login' manually later." >&2
        echo "Alternatively, set GH_TOKEN environment variable for automated authentication." >&2
        return 1
      fi
    else
      echo "GitHub CLI already authenticated" >&2
    fi
  else
    echo "Non-interactive environment detected, skipping GitHub CLI authentication" >&2
    echo "For automated environments, set GH_TOKEN environment variable" >&2
  fi
}

# Install GitHub CLI before anything else
install_github_cli
# Try to authenticate if in interactive environment
try_github_auth || true

if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
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
