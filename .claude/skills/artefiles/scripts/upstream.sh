#!/bin/sh
# upstream.sh [--apply] — for a fork: shows the newest artefiles release and
# whether the fork has it. With --apply it adds the upstream remote if missing,
# fetches the tags and merges that release; it never runs chezmoi apply.
set -eu

here=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
url="${ARTEFILES_UPSTREAM:-https://github.com/artefactory/artefiles.git}"
apply=false
[ "${1:-}" != --apply ] || apply=true

src=$(chezmoi source-path)
origin=$(git -C "$src" remote get-url origin 2> /dev/null || echo "")
if [ "$origin" = "$url" ] || [ "${origin%.git}" = "${url%.git}" ]; then
  echo "origin is artefiles itself, not a fork: use chezmoi update." >&2
  exit 1
fi

latest=$(git ls-remote --tags --refs "$url" 'v[0-9]*' | sed 's|.*refs/tags/||' | sort -V | tail -n 1)
[ -n "$latest" ] || {
  echo "No release found at $url." >&2
  exit 1
}
if git -C "$src" rev-parse -q --verify "refs/tags/$latest" > /dev/null \
  && git -C "$src" merge-base --is-ancestor "$latest" HEAD; then
  echo "The fork already has $latest."
  exit 0
fi

echo "Newest release: $latest, not merged into the fork yet. Plan:"
git -C "$src" remote get-url upstream > /dev/null 2>&1 || echo "  git -C $src remote add upstream $url"
echo "  git -C $src fetch upstream --tags"
echo "  git -C $src merge $latest"
echo "  then: scripts/drift.sh, chezmoi apply once the drift is understood, git push"
$apply || exit 0

if [ -n "$(git -C "$src" status --porcelain)" ]; then
  echo "The source has uncommitted edits; commit or stash them first." >&2
  exit 1
fi
git -C "$src" remote get-url upstream > /dev/null 2>&1 || git -C "$src" remote add upstream "$url"
git -C "$src" fetch --quiet upstream --tags
git -C "$src" merge --no-edit "$latest" || {
  echo "The merge stopped on conflicts: resolve them in $src, then git commit." >&2
  exit 1
}
sh "$here/drift.sh"
