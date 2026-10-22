#!/bin/sh
# envrc-uv.sh [--nested] [--apply] [--force] [DIR] — the direnv .envrc that
# activates a uv project's venv on cd. Prints it; --apply writes DIR/.envrc
# (refusing to replace one without --force) and runs direnv allow. --nested is
# for a project inside another one (a jj workspace, say): it keeps the parent's
# .envrc but drops the parent's venv.
set -eu

nested=false apply=false force=false dir=.
for arg in "$@"; do
  case "$arg" in
    --nested) nested=true ;;
    --apply) apply=true ;;
    --force) force=true ;;
    *) dir="$arg" ;;
  esac
done

envrc() {
  if $nested; then
    echo 'source_up'
    # shellcheck disable=SC2016 # written to .envrc, expanded by direnv
    echo '[[ -n $VIRTUAL_ENV ]] && PATH_rm "$VIRTUAL_ENV/bin"'
    echo 'unset UV_PROJECT_ENVIRONMENT'
  fi
  # direnv's built-in layout uv (2.38+) needs pyproject.toml and uv.lock;
  # --inexact keeps packages the lockfile does not list.
  echo 'layout uv --inexact'
}

if ! $apply; then
  envrc
  exit 0
fi
if [ ! -f "$dir/pyproject.toml" ] || [ ! -f "$dir/uv.lock" ]; then
  echo "$dir needs a pyproject.toml and a uv.lock first: uv init && uv lock" >&2
  exit 1
fi
if [ -e "$dir/.envrc" ] && ! $force; then
  echo "$dir/.envrc exists; --force replaces it." >&2
  exit 1
fi
envrc > "$dir/.envrc"
echo "Wrote $dir/.envrc"
if command -v direnv > /dev/null 2>&1; then
  (cd "$dir" && direnv allow)
fi
