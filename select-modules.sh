#!/bin/sh
# Module checklist run by install.sh before `chezmoi init`.
#
# Every optional module is shown as [x] (will be installed) or [ ] (will not),
# with its help text, followed by a Submit row. Type a module's number to toggle
# it, n for none, the Submit number (or Enter) to continue; a summary then asks
# for confirmation before anything starts.
# Choosing one module of an alternative pair deselects the other.
#
# The module names, help texts and alternative pairs are read from
# .chezmoi.toml.tmpl, the one place that defines them. The UI goes to stderr and
# the result, a JSON array of bare module names in list order, to stdout. Exits
# 2 without output when there is no terminal to read, and 1 when the input ends
# before the selection is confirmed.
#
# ARTEFILES_SELECT_TTY only exists so tests can feed the answers.

set -eu

here="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
template="${here}/.chezmoi.toml.tmpl"
tty_dev="${ARTEFILES_SELECT_TTY:-/dev/tty}"

( : < "$tty_dev" ) 2> /dev/null || exit 2
exec 3< "$tty_dev"

# shellcheck disable=SC2016 # the patterns match literal `$choices` and `$pairs`
choices=$(sed -nE 's/^# \[\[ \$choices = append \$choices "([^"]*)" \]\] #$/\1/p' "$template")
# shellcheck disable=SC2016
pairs=$(sed -nE 's/^# \[\[ \$pairs := list (.*) \]\] #$/\1/p' "$template" |
  grep -oE '"[a-z_]+" "[a-z_]+"' | tr -d '"')
[ -n "$choices" ] || exit 1
count=$(printf '%s\n' "$choices" | wc -l | tr -d ' ')

selected=","
notice=""

name_of() { printf '%s\n' "$choices" | sed -n "${1}p" | sed 's/ | .*//'; }
is_selected() {
  case "$selected" in
    *",$1,"*) return 0 ;;
  esac
  return 1
}
partner_of() { printf '%s\n' "$pairs" | awk -v m="$1" '$1==m{print $2} $2==m{print $1}'; }

# The selection as a JSON array of names, in list order.
result() {
  out=""
  for i in $(seq 1 "$count"); do
    name=$(name_of "$i")
    if is_selected "$name"; then
      out="${out:+${out},}\"${name}\""
    fi
  done
  printf '[%s]' "$out"
}

# The selection as a readable list, in list order.
summary() {
  out=""
  for i in $(seq 1 "$count"); do
    name=$(name_of "$i")
    if is_selected "$name"; then
      out="${out:+${out}, }${name}"
    fi
  done
  printf '%s' "$out"
}

render() {
  if [ -t 2 ]; then
    printf '\033[H\033[2J' >&2
  fi
  {
    printf 'Select the optional modules to install\n\n'
    printf '  [x] will be installed    [ ] will not be installed\n\n'
    i=0
    printf '%s\n' "$choices" | while IFS= read -r line; do
      i=$((i + 1))
      name="${line%% | *}"
      help="${line#* | }"
      if is_selected "$name"; then mark="[x]"; else mark="[ ]"; fi
      printf '%3s) %s %-13s %s\n' "$i" "$mark" "$name" "$help"
    done
    printf '%3s) %s\n' "$((count + 1))" ">> Submit: validate these choices and continue"
    printf '\n'
    if [ -n "$notice" ]; then
      printf '%s\n\n' "$notice"
    fi
  } >&2
  notice=""
}

toggle() {
  name=$(name_of "$1")
  if is_selected "$name"; then
    selected=$(printf '%s' "$selected" | sed "s/,${name},/,/")
    return
  fi
  selected="${selected}${name},"
  for other in $(partner_of "$name"); do
    if is_selected "$other"; then
      selected=$(printf '%s' "$selected" | sed "s/,${other},/,/")
      notice="${other} was deselected: it is an alternative to ${name}"
    fi
  done
}

# Summary and confirmation. Returns when the user declines, so the list comes back.
finish() {
  chosen=$(summary)
  if [ -n "$chosen" ]; then
    printf '\nYou will install: %s\n' "$chosen" >&2
  else
    printf '\nYou will install no optional modules.\n' >&2
  fi
  printf 'Install these modules? [Y/n] ' >&2
  IFS= read -r confirm <&3 || cancel
  case "$confirm" in
    "" | y | Y | yes | YES | Yes)
      printf 'Choices validated: %s\n' "${chosen:-no optional modules}" >&2
      result
      exit 0
      ;;
  esac
}

cancel() {
  printf 'Selection cancelled.\n' >&2
  exit 1
}

while :; do
  render
  printf 'Type a module number to toggle it, n for none, %s to submit (or Enter): ' "$((count + 1))" >&2
  IFS= read -r answer <&3 || cancel
  case "$answer" in
    n | N)
      selected=","
      notice="Selection cleared."
      ;;
    "")
      finish
      ;;
    *[!0-9]* | 0*)
      notice="${answer} is not a module number (1-${count})"
      ;;
    *)
      if [ "$answer" -eq "$((count + 1))" ]; then
        finish
      elif [ "$answer" -le "$count" ]; then
        toggle "$answer"
      else
        notice="${answer} is not a module number (1-${count})"
      fi
      ;;
  esac
done
