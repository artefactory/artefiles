#!/bin/sh
# Git hooks (pre_commit or prek module): the manager installed, the global
# template hooks every clone gets, and this repository's hooks. Changes nothing.
set -eu

manager=""
for m in prek pre-commit; do
  if command -v "$m" > /dev/null 2>&1; then
    manager="$m"
    break
  fi
done
echo "manager: ${manager:-not installed (pre_commit or prek module)}"

template="$HOME/.git_template/hooks"
for h in pre-commit commit-msg pre-push; do
  if [ -f "$template/$h" ]; then echo "template $h: present"; else echo "template $h: missing: chezmoi apply"; fi
done

if top=$(git rev-parse --show-toplevel 2> /dev/null); then
  hooks=$(git rev-parse --git-path hooks)
  if [ ! -f "$top/.pre-commit-config.yaml" ]; then
    echo "this repository: no .pre-commit-config.yaml"
  elif [ -f "$hooks/pre-commit" ]; then
    echo "this repository: hooks installed"
  else
    echo "this repository: hooks not installed: ${manager:-prek} install"
  fi
fi
