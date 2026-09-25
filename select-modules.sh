#!/bin/sh
# Module checklist run by install.sh before `chezmoi init`.
#
# Every optional module is a row shown as [x] (will be installed) or [ ] (will
# not), with its help text, followed by a Submit row. Move the pointer with the
# up and down arrows (or k and j), press space to toggle the module under it,
# and press Enter on the Submit row to continue; a summary then asks for
# confirmation before anything starts. Enter on a module row toggles it too, n
# clears the selection and q cancels.
# Choosing one module of an alternative pair deselects the other.
#
# The module names, help texts and alternative pairs are read from
# .chezmoi.toml.tmpl, the one place that defines them. The UI goes to stderr and
# the result, a JSON array of bare module names in list order, to stdout. Exits
# 2 without output when there is no terminal to read, and 1 when the input ends
# or the user cancels before the selection is confirmed.
#
# ARTEFILES_SELECT_TTY only exists so tests can feed the keystrokes.

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
cur=1
saved_tty=""

# Single keys are read in raw mode; the terminal is put back on every way out.
restore_tty() {
  if [ -n "$saved_tty" ]; then
    stty "$saved_tty" <&3 2> /dev/null || :
    saved_tty=""
  fi
}
raw_on() {
  if [ -t 3 ]; then
    saved_tty=$(stty -g <&3) && stty -icanon -echo min 1 time 0 <&3
  fi
}
trap restore_tty EXIT
trap 'restore_tty; exit 130' INT
trap 'restore_tty; exit 143' TERM
trap 'restore_tty; exit 129' HUP

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
      if [ "$i" -eq "$cur" ]; then pointer=">"; else pointer=" "; fi
      if is_selected "$name"; then mark="[x]"; else mark="[ ]"; fi
      printf '%s %s %-13s %s\n' "$pointer" "$mark" "$name" "$help"
    done
    if [ "$cur" -eq "$((count + 1))" ]; then pointer=">"; else pointer=" "; fi
    printf '%s %s\n' "$pointer" "[ Submit ] validate these choices and continue"
    printf '\nup/down or k/j move   space toggles   Enter on Submit continues   n clears   q cancels\n'
    if [ -n "$notice" ]; then
      printf '\n%s\n' "$notice"
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

cancel() {
  restore_tty
  printf '\nSelection cancelled.\n' >&2
  exit 1
}

# Summary and confirmation. Returns when the user declines, so the list comes
# back with the pointer on the first row.
finish() {
  chosen=$(summary)
  restore_tty
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
  cur=1
  raw_on
}

# hex_bytes N — the next N bytes of input as hex, empty when the input ended.
hex_bytes() { dd bs=1 count="$1" <&3 2> /dev/null | od -An -tx1 | tr -d ' \n'; }

# read_key — set $key to up, down, toggle, enter, none, quit or other; fails when
# the input ended.
read_key() {
  hex=$(hex_bytes 1)
  case "$hex" in
    "") return 1 ;;
    1b)
      case "$(hex_bytes 2)" in
        5b41 | 4f41) key=up ;;
        5b42 | 4f42) key=down ;;
        *) key=other ;;
      esac
      ;;
    6b) key=up ;;
    6a) key=down ;;
    20 | 78) key=toggle ;;
    0a | 0d) key=enter ;;
    6e | 4e) key=none ;;
    71 | 51 | 03) key=quit ;;
    *) key=other ;;
  esac
}

rows=$((count + 1))
raw_on
while :; do
  render
  read_key || cancel
  case "$key" in
    up)
      cur=$((cur - 1))
      if [ "$cur" -lt 1 ]; then cur=$rows; fi
      ;;
    down)
      cur=$((cur + 1))
      if [ "$cur" -gt "$rows" ]; then cur=1; fi
      ;;
    toggle | enter)
      if [ "$cur" -le "$count" ]; then
        toggle "$cur"
      else
        finish
      fi
      ;;
    none)
      selected=","
      notice="Selection cleared."
      ;;
    quit) cancel ;;
  esac
done
