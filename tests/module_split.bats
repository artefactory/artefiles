#!/usr/bin/env bats
# Verify the cloud/macos_desktop module split: old names are gone, new
# atomic modules (gcloud, colima, aerospace, onepassword) gate independently.

setup() {
  load 'helpers/setup'
  load 'helpers/assertions'
}

@test "no stale 'cloud' or 'macos_desktop' references in source" {
  ! grep -RIn --include='*.tmpl' --include='*.yaml' --include='*.toml' \
    --exclude-dir=.git --exclude-dir=tests \
    -E 'has "(cloud|macos_desktop)" \.modules|^      (cloud|macos_desktop):' \
    "$REPO_ROOT" 2>/dev/null
}

@test "prompt module list matches packages.yaml module keys" {
  local prompt_keys yaml_keys
  prompt_keys=$(grep -oE '"[a-z_]+"' "$REPO_ROOT/.chezmoi.toml.tmpl" \
    | tr -d '"' \
    | grep -E '^(editor|terminal|git_advanced|atuin|python_dev|gcloud|colima|multiplexer|aerospace|onepassword)$' \
    | sort -u)
  yaml_keys=$(awk '/^    modules:$/,/^[^ ]/{ if ($1 ~ /:$/ && $0 ~ /^      [a-z_]+:$/) { gsub(":",""); print $1 } }' \
    "$REPO_ROOT/.chezmoidata/packages.yaml" | sort -u)
  if [ "$prompt_keys" != "$yaml_keys" ]; then
    printf 'prompt keys:\n%s\nyaml keys:\n%s\n' "$prompt_keys" "$yaml_keys" >&2
    return 1
  fi
}

@test "aerospace module: aerospace dir is materialized" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["aerospace"]}'
  chezmoi_apply "$H"
  assert_file_exists "$H/.config/aerospace"
}

@test "onepassword module alone: aerospace dir absent" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["onepassword"]}'
  chezmoi_apply "$H"
  assert_file_absent "$H/.config/aerospace"
}

@test "gcloud and colima modules gate independently" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["gcloud"]}'
  local rendered
  rendered=$(chezmoi_render "$H" "dot_config/fish/config.fish.tmpl")
  echo "$rendered" | grep -q "Google Cloud SDK"

  H2=$(mk_fake_home "$BATS_TEST_TMPDIR/h2")
  seed_chezmoi_config "$H2" '{"modules":["colima"]}'
  rendered=$(chezmoi_render "$H2" "dot_config/fish/config.fish.tmpl")
  ! echo "$rendered" | grep -q "Google Cloud SDK"
}
