#!/bin/sh
# rollback.sh [--apply] [TAG] — move the source back to the release before the
# current one (or TAG). Without --apply it only prints the plan. With --apply
# it checks the tag out and runs the drift check; it never runs chezmoi apply.
set -eu

here=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
apply=false
tag=""
for arg in "$@"; do
  case "$arg" in
    --apply) apply=true ;;
    *) tag="$arg" ;;
  esac
done

src=$(chezmoi source-path)
current=$(git -C "$src" describe --tags --exact-match --match 'v[0-9]*' 2> /dev/null) || {
  echo "The source is not on a release tag (git -C $src status): nothing to roll back to." >&2
  exit 1
}
if [ -z "$tag" ]; then
  tag=$(git -C "$src" tag -l 'v[0-9]*' --sort=-v:refname | awk -v cur="$current" 'found { print; exit } $0 == cur { found = 1 }')
fi
[ -n "$tag" ] || {
  echo "No release before $current." >&2
  exit 1
}

echo "Roll back from $current to $tag:"
echo "  git -C $src checkout --detach $tag"
echo "  then: scripts/drift.sh, and chezmoi apply once the drift is understood"
echo "  The next chezmoi update moves forward to the newest release again."
$apply || exit 0

if [ -n "$(git -C "$src" status --porcelain)" ]; then
  echo "The source has uncommitted edits; commit or stash them first." >&2
  exit 1
fi
git -C "$src" checkout --quiet --detach "$tag"
echo "Source now at $tag."
sh "$here/drift.sh"
