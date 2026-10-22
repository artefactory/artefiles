#!/bin/sh
# The drift check: lists every target that differs from the source, says
# whether its source is a template, and prints the commands that keep either
# side. Changes nothing.
set -eu

dest=$(chezmoi execute-template '{{ .chezmoi.destDir }}')
src=$(chezmoi source-path)

changes=$(chezmoi status --exclude=scripts,externals)
if [ -z "$changes" ]; then
  echo "No drift: every target matches the source."
else
  printf '%s\n' "$changes" | while read -r code path; do
    target="$dest/$path"
    source_file=$(chezmoi source-path "$target" 2> /dev/null || echo "")
    case "$code" in
      *A*) echo "$path: missing, created on apply." ;;
      *D*) echo "$path: deleted on apply (.chezmoiremove or a retired file)." ;;
      *)
        case "$source_file" in
          *.tmpl) keep="port the edit into $source_file by hand, or: chezmoi merge $target" ;;
          *) keep="chezmoi re-add $target" ;;
        esac
        echo "$path: differs. See: chezmoi diff $target"
        echo "    keep yours: $keep"
        echo "    take the source: chezmoi apply $target"
        ;;
    esac
  done
fi

if git -C "$src" rev-parse > /dev/null 2>&1 && [ -n "$(git -C "$src" status --porcelain)" ]; then
  echo "The source has uncommitted edits (git -C $src status); chezmoi update stops on them."
fi
