#!/bin/sh
# Simulate a new user's install in a throwaway home that is not yours.
#
#   ./sandbox.sh [--modules a,b] [--offers] [--gh-token] [--keep] [--command CMD] [-- CHEZMOI_INIT_ARGS...]
#
# By default it runs the real install.sh interactively inside the sandbox: the
# gh check and login, chezmoi, the email prompt, the module list with its help
# texts and the alternatives guard, the files applied from this checkout, and
# the end-of-install offers (fish as default shell, star the repository). Then
# it opens a shell in the sandbox, or runs CMD. Your real home and ~/.config
# are never read or written.
#
# Every side effect on your machine is replaced by a stub that prints
# "(sandbox) would run: ..." at the end: brew, curl and wget downloads, the gh
# login, starring, sudo and chsh, and chezmoi's scripts and externals, so
# nothing is installed. Reads still work, so the star check and your name and
# email come from GitHub when a token is available.
#
#   --modules a,b  skip install.sh and the prompts, seed these modules
#   --offers       with --modules, also show the end-of-install offers
#   --gh-token     lend your real `gh` token so GitHub answers for real; without
#                  it (and without GH_TOKEN) gh is logged out, as for a new user,
#                  and install.sh asks for a login that is only simulated
#   --keep         leave the sandbox on disk
#   -- ARGS        extra arguments for chezmoi init (answers to its prompts)
#
# For a full Linux install in a container, use docker-test.sh.

set -eu

modules=""
modules_set=false
offers=false
lend_token=false
keep=false
command_to_run=""

usage() {
  echo "Usage: $0 [--modules a,b] [--offers] [--gh-token] [--keep] [--command CMD] [-- CHEZMOI_INIT_ARGS...]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --modules)
      modules="${2:?--modules requires a comma-separated list}"
      modules_set=true
      shift 2
      ;;
    --offers)
      offers=true
      shift
      ;;
    --gh-token)
      lend_token=true
      shift
      ;;
    --keep)
      keep=true
      shift
      ;;
    --command)
      command_to_run="${2:?--command requires a command}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

source_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

# The template holds the single list of alternative pairs; read it from there
# instead of copying it here. Only --modules needs the check: in the install
# flow chezmoi init enforces it itself.
if [ "$modules_set" = "true" ]; then
  # shellcheck disable=SC2016 # the pattern matches a literal `$pairs`
  pairs=$(sed -nE 's/^# \[\[ \$pairs := list (.*) \]\] #$/\1/p' "${source_dir}/.chezmoi.toml.tmpl" |
    grep -oE '"[a-z_]+" "[a-z_]+"' | tr -d '"')
  selected=",${modules},"
  printf '%s\n' "$pairs" | while read -r a b; do
    [ -n "$a" ] || continue
    case "$selected" in
      *",${a},"*)
        case "$selected" in
          *",${b},"*)
            echo "${a} and ${b} are alternatives: choose one" >&2
            exit 1
            ;;
        esac
        ;;
    esac
  done
fi

real_chezmoi="$(command -v chezmoi 2> /dev/null || true)"
[ -n "$real_chezmoi" ] || {
  echo "chezmoi must be installed to run the sandbox" >&2
  exit 1
}
real_gh="$(command -v gh 2> /dev/null || true)"
borrowed_token=""
if [ "$lend_token" = "true" ]; then
  [ -n "$real_gh" ] || {
    echo "--gh-token needs gh installed" >&2
    exit 1
  }
  borrowed_token="$("$real_gh" auth token)"
fi

home="$(mktemp -d "${TMPDIR:-/tmp}/artefiles-sandbox.XXXXXX")"
stubs="${home}.stubs"
copy="${home}.src"
mkdir -p "${stubs}/brew-prefix/bin" "$copy"
cleanup() {
  if [ "$keep" = "true" ]; then
    echo "Sandbox kept at ${home}" >&2
  else
    rm -rf "$home" "$stubs" "$copy"
  fi
}
trap cleanup EXIT

# chezmoi downloads every archive external to read the source state, even with
# --exclude=externals, so the sandbox applies from a copy without the template.
(cd "$source_dir" && tar --exclude=./.git --exclude=./.workspaces \
  --exclude=./.chezmoiexternal.toml.tmpl -cf - .) | tar -xf - -C "$copy"

# Stubs only append to a log: the offers silence the tools' own output, so the
# sandbox prints the log itself once the install is done.
actions_log="${stubs}/actions.log"
: > "$actions_log"

# Commands that would change the machine: log them and do nothing.
for tool in sudo chsh curl wget; do
  printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 1\n' "$tool" "$actions_log" > "${stubs}/${tool}"
done
printf '#!/bin/sh\necho "sudo $*" >> "%s"\nexit 0\n' "$actions_log" > "${stubs}/sudo"
printf '#!/bin/sh\necho "chsh $*" >> "%s"\nexit 0\n' "$actions_log" > "${stubs}/chsh"

# brew: install.sh only asks for its prefix and shellenv, and to install gh.
cat > "${stubs}/brew" << STUB
#!/bin/sh
case "\$1" in
  --prefix) echo "${stubs}/brew-prefix" ;;
  shellenv) ;;
  *) echo "brew \$*" >> "${actions_log}" ;;
esac
STUB

# chezmoi: the install flow must never run scripts or externals.
cat > "${stubs}/chezmoi" << STUB
#!/bin/sh
sub="\${1:-}"
case "\$sub" in init | apply) set -- "\$@" --exclude=scripts,externals ;; esac
if [ "\$sub" = init ] && [ -f "${stubs}/init.args" ]; then
  while IFS= read -r arg; do set -- "\$@" "\$arg"; done < "${stubs}/init.args"
fi
exec "${real_chezmoi}" "\$@"
STUB
: > "${stubs}/init.args"
for arg in "$@"; do
  printf '%s\n' "$arg" >> "${stubs}/init.args"
done

# gh: reads go to the real gh when a token is available, otherwise gh is a new
# user's logged-out gh; writes (login, starring) are only logged.
token_available="false"
if [ -n "$borrowed_token" ] || [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  token_available="true"
fi
cat > "${stubs}/gh" << STUB
#!/bin/sh
log() { echo "gh \$*" >> "${actions_log}"; }
case "\$*" in
  "auth status"*)
    [ "${token_available}" = "true" ] || [ -f "${stubs}/logged-in" ] ;;
  "auth login"*)
    log "\$@"
    echo "(sandbox) GitHub login simulated, nothing was opened" >&2
    touch "${stubs}/logged-in" ;;
  *"-X PUT"* | *"-X POST"* | *"-X PATCH"* | *"-X DELETE"*)
    log "\$@" ;;
  *)
    if [ "${token_available}" = "true" ] && [ -n "${real_gh}" ]; then
      exec "${real_gh}" "\$@"
    fi
    case "\$*" in
      *login*) echo "sandbox-user" ;;
      *email*) echo "sandbox-user@example.com" ;;
      "api user/starred/"*) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
    esac ;;
esac
STUB

# A new user has fish by the time the offers run; stand in for it when missing.
if ! command -v fish > /dev/null 2>&1; then
  printf '#!/bin/sh\nexit 0\n' > "${stubs}/fish"
fi
chmod +x "${stubs}"/*

config_dir="${home}/.config"
mkdir -p "${config_dir}/chezmoi"

# Everything that could resolve to the real home points inside the sandbox, and
# the stubs come first on PATH.
run_in_sandbox() {
  env HOME="$home" XDG_CONFIG_HOME="$config_dir" XDG_DATA_HOME="${home}/.local/share" \
    XDG_CACHE_HOME="${home}/.cache" XDG_STATE_HOME="${home}/.local/state" \
    PATH="${stubs}:${PATH}" ARTEFILES_SHELLS_FILE="${home}/shells" \
    ${borrowed_token:+GH_TOKEN="$borrowed_token"} "$@"
}

show_actions() {
  if [ -s "$actions_log" ]; then
    echo >&2
    sed 's/^/(sandbox) would run: /' "$actions_log" >&2
    : > "$actions_log"
  fi
}

if [ "$modules_set" = "true" ]; then
  module_list=$(printf '%s' "$modules" | awk -F, 'BEGIN { printf "[" } { for (i = 1; i <= NF; i++) if ($i != "") printf "%s\"%s\"", (n++ ? "," : ""), $i } END { printf "]" }')
  cat > "${config_dir}/chezmoi/chezmoi.toml" << CONFIG
sourceDir = "${copy}"

[data]
name = "sandbox"
email = "sandbox@example.com"
credentialHelper = "cache"
modules = ${module_list}
CONFIG
  # The seeded config always differs from the template, which makes chezmoi warn
  # on every run; only show its output when the apply fails.
  if ! apply_output=$(run_in_sandbox chezmoi apply --config "${config_dir}/chezmoi/chezmoi.toml" \
    --source "$copy" --destination "$home" 2>&1); then
    printf '%s\n' "$apply_output" >&2
    exit 1
  fi
  if [ "$offers" = "true" ]; then
    for offer in offer-default-shell.sh offer-star.sh; do
      [ -f "${copy}/${offer}" ] || continue
      run_in_sandbox sh "${copy}/${offer}" || true
    done
    show_actions
  fi
else
  # The real install.sh, from this checkout, into the sandbox.
  run_in_sandbox sh "${copy}/install.sh" --destination "$home" || {
    show_actions
    exit 1
  }
  show_actions
fi

if [ -n "$command_to_run" ]; then
  run_in_sandbox sh -c "$command_to_run"
else
  shell="$(command -v fish 2> /dev/null || echo "${SHELL:-sh}")"
  echo "Sandbox home: ${home} (shell: ${shell}). Exit the shell to leave it." >&2
  run_in_sandbox "$shell" -i || true
fi
