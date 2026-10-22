#!/bin/sh
# Prints the modules chezmoi installs on this machine (stored lists from older
# releases migrated, as apply sees them) and the guides to read for them.
set -eu

skill_dir=$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)

src=$(chezmoi source-path 2> /dev/null) || {
  echo "chezmoi has no source here: artefiles is not installed." >&2
  exit 1
}
if [ ! -f "$src/.chezmoitemplates/modules" ]; then
  echo "The chezmoi source ($src) is not artefiles." >&2
  exit 1
fi

modules=$(chezmoi execute-template '{{ includeTemplate "modules" . }}' | tr -d '[]"' | tr ',' ' ')
echo "Modules: ${modules:-none}"
echo "Guides to read:"
echo "  $skill_dir/references/core.md"
for m in $modules; do
  echo "  $skill_dir/references/$m.md"
done
