#!/bin/sh
# tool-info.sh TOOL — which module installs TOOL (a command or a package name),
# whether it is installed and at which version, the configs chezmoi manages for
# it, and its fish aliases. Changes nothing.
set -eu

here=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
name="${1:?usage: tool-info.sh TOOL}"

# Package names whose command differs; both spellings are accepted.
cmd="$name"
pkg="$name"
for pair in neovim:nvim ripgrep:rg bottom:btm rip2:rip choose-rust:choose \
  difftastic:difft kubernetes-cli:kubectl gcloud-cli:gcloud azure-cli:az opentofu:tofu; do
  p=${pair%%:*} c=${pair#*:}
  if [ "$name" = "$p" ] || [ "$name" = "$c" ]; then
    pkg="$p" cmd="$c"
  fi
done

src=$(chezmoi source-path 2> /dev/null) || {
  echo "chezmoi has no source here: artefiles is not installed." >&2
  exit 1
}

# The module: the darwin package list, else the Linux download gated by a module.
module=$(awk -v pkg="$pkg" '
  /^    modules:$/ { on = 1; next }
  on && /^      [a-z_]+:$/ { m = $1; sub(":", "", m) }
  on && /^ +- / { v = $2; gsub("\047", "", v); n = split(v, parts, "/"); if (parts[n] == pkg) { print m; exit } }
' "$src/.chezmoidata/packages.yaml")
if [ -z "$module" ]; then
  module=$(awk -v bin="\".local/bin/$cmd\"" '
    /has "[a-z_]+" \$modules/ { match($0, /has "[a-z_]+"/); m = substr($0, RSTART + 5, RLENGTH - 6) }
    /^# \[\[ end \]\] #/ { m = "" }
    index($0, "[" bin "]") == 1 { print (m == "" ? "core" : m); exit }
  ' "$src/.chezmoiexternal.toml.tmpl")
fi
echo "$cmd: module ${module:-core or not part of artefiles}"

if command -v "$cmd" > /dev/null 2>&1; then
  echo "  installed: $(command -v "$cmd"), $("$cmd" --version 2>&1 | head -n 1)"
else
  echo "  not installed"
fi

configs=$(chezmoi managed --include=files 2> /dev/null | grep -i "/$cmd\(/\|\.\|$\)\|$cmd/" || true)
if [ -n "$configs" ]; then
  echo "  configs managed by chezmoi:"
  printf '%s\n' "$configs" | sed 's/^/    ~\//'
fi

aliases=$(sh "$here/aliases.sh" "$cmd" 2> /dev/null || true)
if [ -n "$aliases" ]; then
  echo "  fish aliases:"
  printf '%s\n' "$aliases" | sed 's/^/    /'
fi
if [ -n "$module" ] && [ "$module" != core ]; then
  echo "  guide: $(dirname "$here")/references/$module.md"
fi
