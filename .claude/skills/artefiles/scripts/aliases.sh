#!/bin/sh
# aliases.sh TOOL — the fish aliases, functions and abbreviations artefiles
# defines for TOOL, read from the applied files (the source when not applied).
set -eu

tool="${1:?usage: aliases.sh TOOL}"
fish_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
aliases="$fish_dir/aliases.fish"
abbrs="$fish_dir/conf.d/artefiles_abbrs.fish"
if [ ! -f "$aliases" ] && src=$(chezmoi source-path 2> /dev/null); then
  aliases="$src/dot_config/fish/aliases.fish.tmpl"
  abbrs="$src/dot_config/fish/conf.d/private_artefiles_abbrs.fish"
fi
[ -f "$aliases" ] || {
  echo "No fish aliases file found." >&2
  exit 1
}

# A line belongs to TOOL inside its `if type -q TOOL` block, or when the alias
# value starts with TOOL (or a variable named after it, like $eza_long).
awk -v tool="$tool" '
  /^if type -q / { block = ($4 == tool); next }
  /^end/ { block = 0; next }
  /^[[:space:]]*alias / {
    line = $0; sub(/^[[:space:]]*/, "", line)
    value = line; sub(/^[^=]*="?/, "", value); sub(/^\$/, "", value)
    if (block || index(value, tool) == 1) print line
    next
  }
  /^[[:space:]]*function / && block { line = $0; sub(/^[[:space:]]*/, "", line); print line }
' "$aliases"
if [ -f "$abbrs" ]; then
  grep -E "^abbr .*${tool}" "$abbrs" || true
fi
