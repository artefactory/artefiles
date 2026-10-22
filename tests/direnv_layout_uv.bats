#!/usr/bin/env bats
# artefiles ships no direnvrc, so `layout uv` is direnv's built-in: it syncs
# the venv, and a nested project with the .envrc CHEATSHEET.md documents gets
# its own venv instead of the parent's.

setup() {
  load 'helpers/setup'
}

@test "no direnvrc is installed to shadow direnv's built-in layout uv" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["shell_tools"]}'
  run chezmoi_managed "$H"
  [ "$status" -eq 0 ]
  [[ "$output" != *".config/direnv/direnvrc"* ]]
}

@test "a nested project activates its own venv, not the parent's" {
  command -v direnv > /dev/null || skip "direnv is not installed"
  command -v uv > /dev/null || skip "uv is not installed"
  H=$(mk_fake_home)
  mkdir -p "$H/.config/direnv"
  # A direnvrc artefiles installs, if any, is what direnv loads here.
  if chezmoi_managed "$H" | grep -qx .config/direnv/direnvrc; then
    chezmoi_apply "$H" .config/direnv/direnvrc
  fi
  # direnv approves an .envrc by its resolved path; TMPDIR is a symlink on macOS.
  R="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/repo"
  W="$R/.workspaces/ws"
  mkdir -p "$W"
  for d in "$R" "$W"; do
    printf '[project]\nname = "p%s"\nversion = "0"\nrequires-python = ">=3.9"\n' "$RANDOM" > "$d/pyproject.toml"
  done
  echo 'layout uv --inexact' > "$R/.envrc"
  # The nested .envrc of CHEATSHEET.md, from source_up to layout uv.
  sed -n '/^source_up$/,/^layout uv --inexact$/p' "$REPO_ROOT/CHEATSHEET.md" > "$W/.envrc"
  [ -s "$W/.envrc" ]
  e() {
    env -i HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
      PATH="$(dirname "$(command -v uv)"):$(dirname "$(command -v direnv)"):/usr/bin:/bin" \
      UV_PYTHON_DOWNLOADS=never UV_OFFLINE=1 "$@"
  }
  (cd "$R" && e uv lock -q) && (cd "$W" && e uv lock -q)
  e direnv allow "$R" && e direnv allow "$W"
  run e direnv exec "$W" sh -c 'echo "VIRTUAL_ENV=$VIRTUAL_ENV"'
  [[ "$output" == *"VIRTUAL_ENV=$W/.venv"* ]]
  [ -d "$W/.venv" ]
}
