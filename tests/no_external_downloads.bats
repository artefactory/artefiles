#!/usr/bin/env bats
# chezmoi downloads every archive external to read the source state, even with
# --exclude=externals. The helpers therefore run chezmoi from a copy of the
# checkout without the externals template, so no test downloads anything.

setup() {
  load 'helpers/setup'
}

# unreachable_checkout — a copy of the checkout whose externals template points
# at a host nothing listens on; sets REPO_ROOT to it.
unreachable_checkout() {
  fake="$BATS_TEST_TMPDIR/checkout"
  mkdir -p "$fake"
  (cd "$REPO_ROOT" && tar --exclude=./.git --exclude=./.workspaces -cf - .) | tar -xf - -C "$fake"
  cat > "$fake/.chezmoiexternal.toml.tmpl" << 'EXTERNAL'
[".local/bin/tool"]
  type = "archive-file"
  url = "http://127.0.0.1:9/tool.tar.gz"
  path = "tool"
EXTERNAL
  export REPO_ROOT="$fake"
}

@test "apply never tries to download an external" {
  unreachable_checkout
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor"]}'
  chezmoi_apply "$H"
  [ -e "$H/.config/nvim" ]
}

@test "managed never tries to download an external" {
  unreachable_checkout
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  chezmoi_managed "$H" > /dev/null
  chezmoi_managed_with_scripts "$H" > /dev/null
}

@test "the test source has no externals template and is otherwise the checkout" {
  src=$(test_source)
  [ ! -e "$src/.chezmoiexternal.toml.tmpl" ]
  [ -f "$src/.chezmoi.toml.tmpl" ]
  [ -f "$src/.chezmoiignore" ]
  [ ! -e "$src/.git" ]
}

@test "the test source is built once and reused" {
  first=$(test_source)
  touch "$first/marker"
  second=$(test_source)
  [ "$first" = "$second" ]
  [ -e "$second/marker" ]
}

@test "rendering the externals template still uses the real checkout" {
  grep -q 'REPO_ROOT' "$REPO_ROOT/tests/helpers/setup.bash"
  [ -f "$REPO_ROOT/.chezmoiexternal.toml.tmpl" ]
}
