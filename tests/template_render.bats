#!/usr/bin/env bats
# Render-correctness regression guards.
#
# Motivated by a real regression: dropping the .tmpl extension on a file
# that uses chezmoi:template:left-delimiter directives (here, nvim's
# init.lua.tmpl with `-- [[ ... ]] --`) silently turns the OS-conditional
# blocks into literal Lua comments. Tests that only check tests still pass
# don't catch this — only render-correctness checks do.

setup() {
  load 'helpers/setup'
}

# Common Go-template keywords that appear inside chezmoi-recognized
# delimiters. Any rendered output containing one of these wrapped in `{{ }}`
# or `[[ ]]` (with optional `#` / `--` / `//` comment-style padding before
# the open delimiter and after the close) is a leftover directive — the
# file was treated as a plain copy, not a template.
_TEMPLATE_KEYWORD_RE='([-#/]+[[:space:]])?(\{\{|\[\[)[[:space:]-]*(if|else|end|range|with|define|block|template)\b'

@test "every .tmpl renders without leftover template directives" {
  H=$(mk_fake_home)
  all=$(yq -r '.packages.darwin.modules | keys | .[]' "$REPO_ROOT/.chezmoidata/packages.yaml" \
        | jq -R . | jq -sc .)
  seed_chezmoi_config "$H" "$(jq -nc --argjson m "$all" '{modules:$m}')"

  fail=0
  while IFS= read -r tmpl; do
    [ -n "$tmpl" ] || continue
    rel=${tmpl#"$REPO_ROOT"/}
    # Render via chezmoi to honor the file's own template directives.
    rendered=$(chezmoi_render "$H" "$rel" 2>/dev/null) || continue
    if printf '%s\n' "$rendered" | grep -qE "$_TEMPLATE_KEYWORD_RE"; then
      echo "$rel: rendered output contains leftover template directive (file may have lost .tmpl handling)" >&2
      printf '%s\n' "$rendered" | grep -nE "$_TEMPLATE_KEYWORD_RE" | head -3 >&2
      fail=1
    fi
  done < <(find "$REPO_ROOT" -type f -name '*.tmpl' \
            -not -path "$REPO_ROOT/.workspaces/*" \
            -not -path "$REPO_ROOT/tests/*")
  [ $fail = 0 ]
}

@test "non-.tmpl source files contain no chezmoi:template directives" {
  fail=0
  while IFS= read -r f; do
    rel=${f#"$REPO_ROOT"/}
    case "$rel" in
      .git/*|.workspaces/*|tests/*) continue ;;
    esac
    if grep -q 'chezmoi:template:' "$f" 2>/dev/null; then
      echo "$rel: contains chezmoi:template directive but is not a .tmpl file" >&2
      fail=1
    fi
  done < <(find "$REPO_ROOT" -type f -not -name '*.tmpl' \
            -not -path "$REPO_ROOT/.git/*" \
            -not -path "$REPO_ROOT/.workspaces/*" \
            -not -path "$REPO_ROOT/tests/*")
  [ $fail = 0 ]
}

@test "non-.tmpl source files contain no template-directive syntax" {
  # The actual regression-finder: a file with go-template keywords inside
  # chezmoi-recognized delimiters but no .tmpl extension is being copied
  # verbatim. Catches the #95 nvim regression where init.lua.tmpl was
  # demoted to init.lua but kept its `-- [[ if eq .chezmoi.os ... ]] --`
  # blocks.
  # .chezmoiignore is exempt: chezmoi always template-renders it regardless
  # of extension, so its directives are never "leftover".
  fail=0
  while IFS= read -r f; do
    rel=${f#"$REPO_ROOT"/}
    case "$rel" in
      .git/*|.workspaces/*|tests/*|CHEATSHEET.md|README.md|CHANGELOG.md|CLAUDE.md|.chezmoiignore) continue ;;
    esac
    # Skip binary-encoded files
    file --mime-encoding "$f" 2>/dev/null | grep -q binary && continue
    if grep -qE "$_TEMPLATE_KEYWORD_RE" "$f" 2>/dev/null; then
      echo "$rel: contains template directive but lacks .tmpl extension" >&2
      grep -nE "$_TEMPLATE_KEYWORD_RE" "$f" | head -2 >&2
      fail=1
    fi
  done < <(find "$REPO_ROOT" -type f -not -name '*.tmpl' \
            -not -path "$REPO_ROOT/.git/*" \
            -not -path "$REPO_ROOT/.workspaces/*" \
            -not -path "$REPO_ROOT/tests/*")
  [ $fail = 0 ]
}
