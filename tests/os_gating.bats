#!/usr/bin/env bats
# Verify .chezmoiscripts/{linux,darwin}/* never leak across OS boundaries.
# CI runs this on both bats-linux and bats-macos so both directions are
# covered without needing to fake .chezmoi.os.

setup() {
  load 'helpers/setup'
}

@test "no cross-OS scripts appear in chezmoi managed list" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":[]}'
  managed=$(chezmoi_managed_with_scripts "$H")

  case "$(uname -s)" in
    Darwin) other=linux ;;
    Linux)  other=darwin ;;
    *) skip "unsupported OS: $(uname -s)" ;;
  esac

  if printf '%s\n' "$managed" | grep -q "\.chezmoiscripts/${other}/"; then
    echo "Found ${other}-only scripts on $(uname -s):" >&2
    printf '%s\n' "$managed" | grep "\.chezmoiscripts/${other}/" >&2
    return 1
  fi
}

@test "every script in .chezmoiscripts/<os>/ has its OS-mate ignored" {
  H=$(mk_fake_home)
  seed_chezmoi_config "$H" '{"modules":["editor","terminal","atuin","gcloud","colima","git_advanced","onepassword","multiplexer","python_dev","aerospace","agent_skills"]}'
  managed=$(chezmoi_managed_with_scripts "$H")

  case "$(uname -s)" in
    Darwin) own=darwin ;;
    Linux)  own=linux ;;
    *) skip "unsupported OS: $(uname -s)" ;;
  esac

  for f in "$REPO_ROOT"/.chezmoiscripts/${own}/*.sh "$REPO_ROOT"/.chezmoiscripts/${own}/*.sh.tmpl; do
    [ -f "$f" ] || continue
    rel=${f#"$REPO_ROOT"/}
    base=$(basename "${rel%.tmpl}")
    # chezmoi managed strips run_<once|onchange>_ and the optional
    # before_/after_ ordering modifier from script target paths.
    target=$(dirname "$rel")/$(printf '%s\n' "$base" \
      | sed -E 's/^run_(once|onchange)_//' \
      | sed -E 's/^(before|after)_//')
    if ! printf '%s\n' "$managed" | grep -qxF "$target"; then
      echo "$own script not in managed list with all modules on: $rel (expected target $target)" >&2
      return 1
    fi
  done
}
