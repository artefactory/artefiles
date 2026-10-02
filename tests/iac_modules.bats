#!/usr/bin/env bats
# terraform and opentofu are two optional modules: pick the infrastructure-as-code
# CLI you use. OpenTofu is the open-source alternative to Terraform.

setup() {
  load 'helpers/setup'
}

PKG=.chezmoidata/packages.yaml
DARWIN_TMPL=.chezmoiscripts/darwin/run_onchange_darwin-install-packages.sh.tmpl

@test "packages.yaml defines both modules" {
  [ "$(yq -r '.packages.darwin.modules.terraform.brews[0]' "$REPO_ROOT/$PKG")" = "hashicorp/tap/terraform" ]
  [ "$(yq -r '.packages.darwin.modules.opentofu.brews[0]' "$REPO_ROOT/$PKG")" = "opentofu" ]
}

@test "the init prompt offers both modules" {
  prompt_module_names | grep -qx terraform
  prompt_module_names | grep -qx opentofu
}

@test "each module installs only its own brew on macOS" {
  H=$(mk_fake_home "$BATS_TEST_TMPDIR/tf")
  seed_chezmoi_config "$H" '{"modules":["terraform"]}'
  tf=$(chezmoi_render "$H" "$DARWIN_TMPL")
  printf '%s\n' "$tf" | grep -qxF 'brew "hashicorp/tap/terraform"'
  if printf '%s\n' "$tf" | grep -qxF 'brew "opentofu"'; then return 1; fi

  H=$(mk_fake_home "$BATS_TEST_TMPDIR/tofu")
  seed_chezmoi_config "$H" '{"modules":["opentofu"]}'
  tofu=$(chezmoi_render "$H" "$DARWIN_TMPL")
  printf '%s\n' "$tofu" | grep -qxF 'brew "opentofu"'
  if printf '%s\n' "$tofu" | grep -qxF 'brew "hashicorp/tap/terraform"'; then return 1; fi

  H=$(mk_fake_home "$BATS_TEST_TMPDIR/none")
  seed_chezmoi_config "$H" '{"modules":[]}'
  none=$(chezmoi_render "$H" "$DARWIN_TMPL")
  ! printf '%s\n' "$none" | grep -qE 'terraform|opentofu'
}

@test "README lists both modules and calls OpenTofu the open-source alternative" {
  grep -qE '^\| `terraform` \|' "$REPO_ROOT/README.md"
  grep -qE '^\| `opentofu` \|.*open-source fork of Terraform.*Alternative to terraform: pick one' "$REPO_ROOT/README.md"
}

@test "terraform is pinned to a version in .chezmoidata/versions.yaml" {
  version=$(yq -r '.versions.terraform' "$REPO_ROOT/.chezmoidata/versions.yaml")
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "the terraform external is built from the pinned version, not a render-time lookup" {
  grep -qF '.versions.terraform' "$REPO_ROOT/.chezmoiexternal.toml.tmpl"
  if grep -rn 'checkpoint-api' "$REPO_ROOT/.chezmoiexternal.toml.tmpl"; then return 1; fi
}
