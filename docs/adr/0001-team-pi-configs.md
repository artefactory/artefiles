# ADR-0001: Ship team pi packages by merging them into the user's settings

**Date:** 2026-11-05
**Status:** Proposed
**Deciders:** artefiles maintainers
**Issue:** #242

---

## Context

The team wants every artefiles machine to get the same set of pi coding-agent packages.
pi is a coding agent; its packages add extensions, skills and prompts.
pi reads its personal settings from `~/.pi/agent/settings.json`, and the `packages` key in that file lists the packages.
That same file also holds the user's own preferences, and pi writes to it itself: `pi install` adds entries.
So artefiles cannot simply own the file without fighting both the user and pi.

chezmoi is the tool that writes artefiles onto a machine.
Users receive changes with `chezmoi update`, which pulls the repo and then applies it.
`install.sh` runs `chezmoi apply --keep-going`.
The question is how to deliver the team list so that three things hold together:
team changes reach machines that are already set up, local edits survive, and pi keeps the package contents up to date.

**Key constraints:**
- A user's own keys and packages in `settings.json` must survive every apply.
- Writes made by pi itself (`pi install`, `/settings`) must survive every apply.
- A change to the team list must reach machines installed before the change.
- An apply must not fail, or stop at a prompt, on a machine where the file was edited.
- Nothing beyond chezmoi should be required at apply time (`jq` is not in `.chezmoidata/packages.yaml`).

---

## Evidence

### E1. chezmoi with a locally edited managed file and no terminal

The test runs chezmoi v2.62.1 in a sandbox, with stdin set to `/dev/null`.
HOME, XDG_CONFIG_HOME, `--source`, `--destination`, `--config` and `--persistent-state` all point to temporary paths.
Three targets hold the same team list: `plain.json` (a plain managed file), `create_seed.json` and `modify_merged.json`.
`zz_other.json` is an unrelated plain file that sorts after `plain.json`.
`modify_merged.json` holds the first E2 template (the `uniq` union).
A first `apply` writes the four targets.
The user then writes `{"packages":["npm:team-a","npm:mine"],"theme":"mine"}` into the three pi targets.
The table starts after that edit.

| Step | Command | Exit | Result |
|---|---|---|---|
| 1 | `apply`, source unchanged | 1 | `chezmoi: .pi/agent/plain.json: could not open a new TTY: open /dev/tty: device not configured`. No file is overwritten. |
| 2 | team adds `npm:team-b`, `zz_other` goes to v2; `apply` | 1 | Same error. `merged` becomes `{"packages":["npm:team-a","npm:team-b","npm:mine"],"theme":"mine"}`. `seed` is unchanged. **`zz_other` stays at v1**: the error stops the whole apply. |
| 3 | `apply --keep-going` | 1 | Same error. `zz_other` reaches v2; `plain` is still not updated. |
| 4 | `apply --force` | 0 | `plain` becomes `{"packages":["npm:team-a","npm:team-b"]}`: the user's `theme` and `npm:mine` are lost. |
| 5 | delete `merged`, `apply` | 0 | `modify_` creates the file from the team list (empty stdin). |
| 6 | `status` | 0 | Empty: the merge is idempotent. |

`chezmoi update --help` says: "Pull changes from the source repo and apply any changes."
The help also lists `-a, --apply  Apply after pulling (default true)`.
So the apply results above also hold for `chezmoi update`.
That command was not run here, because it needs a git remote.

Conclusions:
- A plain managed file never silently overwrites a local edit.
- Without a terminal, one edited file makes every apply exit 1.
- Without `--keep-going`, that error also blocks every target that sorts after the edited file.
- `create_` never delivers a team change.
- `modify_` delivers the change and keeps the user's keys.

### E2. The `modify_` merge needs no external tool

Both templates below use only chezmoi's built-in template functions.
Both read the team list from `.pi.packages`, the key the Decision puts in `.chezmoidata/packages.yaml`.

**Union by exact value.** E1's `modify_merged.json` is this template, except that E1's sandbox named the key `.team.packages`:

```gotemplate
{{- /* chezmoi:modify-template */ -}}
{{- $cur := dict -}}
{{- if .chezmoi.stdin | trim -}}{{- $cur = fromJson .chezmoi.stdin -}}{{- end -}}
{{- $mine := list -}}
{{- if hasKey $cur "packages" -}}{{- $mine = $cur.packages -}}{{- end -}}
{{- $cur = setValueAtPath "packages" (concat .pi.packages $mine | uniq) $cur -}}
{{- toPrettyJson $cur }}
```

`uniq` removes only exact duplicates, so it does not meet the contract in Implementation Notes.
With the team list `["npm:team-a","npm:team-b"]` and this user file:

```json
{"theme":"mine","packages":["npm:mine","npm:team-a",{"source":"npm:team-b","extensions":["x.ts"]}]}
```

it gives `["npm:team-a","npm:team-b","npm:mine",{"extensions":["x.ts"],"source":"npm:team-b"}]`.
`npm:team-b` appears twice: once as the team string and once as the user's object.

**Union by source.** This template meets the contract:

```gotemplate
{{- /* chezmoi:modify-template */ -}}
{{- $cur := dict -}}
{{- if .chezmoi.stdin | trim -}}{{- $cur = fromJson .chezmoi.stdin -}}{{- end -}}
{{- $team := dict -}}
{{- range .pi.packages -}}{{- $_ := set $team . true -}}{{- end -}}
{{- $override := dict -}}
{{- $rest := list -}}
{{- range (get $cur "packages" | default list) -}}
{{-   $src := . -}}
{{-   if kindIs "map" . -}}{{- $src = .source -}}{{- end -}}
{{-   if not (hasKey $team $src) -}}{{- $rest = append $rest . -}}
{{-   else if kindIs "map" . -}}{{- $_ := set $override $src . -}}
{{-   end -}}
{{- end -}}
{{- $out := list -}}
{{- range .pi.packages -}}{{- $out = append $out (get $override . | default .) -}}{{- end -}}
{{- $cur = setValueAtPath "packages" (concat $out $rest) $cur -}}
{{- toPrettyJson $cur }}
```

It was rendered with `chezmoi execute-template --with-stdin -f <template> < <fixture>`, in the same sandbox as E1:

| stdin fixture | Exit | `packages` in the output |
|---|---|---|
| empty | 0 | `["npm:team-a","npm:team-b"]` |
| the user file above | 0 | `["npm:team-a",{"extensions":["x.ts"],"source":"npm:team-b"},"npm:mine"]`, and `theme` is kept |
| `{"theme":"x"}` (no `packages` key) | 0 | `["npm:team-a","npm:team-b"]`, and `theme` is kept |
| its own output for the user file | 0 | byte-identical to its input (`cmp`): the merge is idempotent |
| `{"packages":[` (invalid JSON) | 1 | none; `error calling fromJson: unexpected EOF` |

The union-by-source template was verified with `execute-template` only.
E1's `apply` runs used the union-by-value template.

So option 3 does not need `jq`, or any other tool, at apply time.

### E3. pi's update commands (docs only; pi is not installed on the test machine)

From https://pi.dev/docs/latest/cli:
- "Running `pi update` without a target updates Pi itself."
- `pi update --extensions`: "Update all installed packages".
- `pi update --all`: "Update Pi and all installed packages".
- "`pi update --self`, `pi update self`, and `pi update pi` are aliases for `pi update`."

From https://pi.dev/docs/latest/packages:
- "Personal installs are written to `~/.pi/agent/settings.json`." So pi writes the file that artefiles would manage.
- "An npm package is reinstalled when the registry has a newer version that matches the specification."
- "Git tags and commits are also pinned; package updates reconcile the checkout but do not move a configured ref."
- "Versioned npm specifications are pinned."
- For a failed startup install, "Pi tries to install it again on the next start or `/reload`." So pi installs declared packages when it starts.
- Entries can be objects (`{"source": "npm:…", "extensions": […], …}`). The page does not document the plain-string form.

pi's source accepts both forms (earendil-works/pi at commit `ccff987`, `packages/coding-agent/src/core/`):
- `settings-schema.ts:171-183`: `PackageSourceSchema` is a union of a string ("Load all resources from the package.") and an object with `source`.
- `settings-schema.ts:314-317`: `packages` is an array of that union, described as "npm or git package sources, as strings or objects with resource filtering."
- `package-manager.ts:1576-1577`: `getPackageSourceString` reads the source as the string itself, or as `.source` for an object.
- `package-manager.ts:922`: `pi install` appends the bare string. So in practice user files hold strings.

From https://pi.dev/docs/latest/settings: "Project settings override agent-directory settings. Resource lists are combined."
The page has no setting that updates packages automatically.

So a bare `pi update` does **not** update packages.
Packages are updated only by `pi update --extensions`, `pi update --all` or `pi update <source>`.

---

## Options Considered

| | 1. Plain managed file | 2. `create_` (seed once) | 3. `modify_` JSON merge | 4. Package list only, pi owns contents |
|---|---|---|---|---|
| Overwrites user or pi edits | Only with `--force`. Without it, the apply fails (E1 step 1) | Never | Never for other keys. For `packages`, a union by source keeps the user's entries, and a user object for a team source replaces the team string | Depends on the mechanism (1, 2 or 3) |
| Team updates reach existing machines | Only after `--force` or an answer at the prompt | **Never** | Yes, on the next apply | Depends on the mechanism |
| Apply without a terminal | Exit 1 once the file has drifted; without `--keep-going`, later targets are blocked too | Fine | Fine | Depends on the mechanism |
| pi updates package contents | Same in every option: pi installs missing packages at start; updating them needs `pi update --extensions` | Same | Same | Same: this option is about who owns what |
| Tooling at apply time | chezmoi | chezmoi | chezmoi only (E2) | — |

### Option 1: Plain managed `settings.json`

**Description:** artefiles owns the whole file.

**Pros:** It is the simplest option. `chezmoi diff` shows drift exactly.

**Cons:** pi rewrites this file on every `pi install` (E3), so the file drifts on every machine that uses pi.
After that, every non-interactive apply exits 1, and without `--keep-going` it blocks unrelated targets (E1 steps 1–2).
In a terminal the user gets a prompt on every update, and answering "overwrite" loses their keys (step 4).

**Why ruled out:** It breaks the constraints that user and pi edits must survive and that applies must not fail.

### Option 2: `create_` seed

**Description:** artefiles writes the file only when it does not exist yet.
The VS Code settings already work this way (`dot_config/Code/User/create_settings.json.tmpl`).

**Pros:** It never conflicts and never fails. It is already used in this repo.

**Cons:** A change to the team list never reaches a machine that already has the file (E1 step 2, `seed`).

**Why ruled out:** The team list must reach machines that are already installed. That is the main point of the issue.

### Option 3: `modify_` JSON merge

**Description:** A `modify_` template reads the current file and writes it back.
It adds the team packages and keeps every other key and every user package.

**Pros:** Team changes reach every machine. User and pi edits survive. The apply never needs a prompt. No `jq` is needed (E2). The merge is idempotent (E1 step 6, E2).

**Cons:**
- The merge is a union. A package the team later removes stays in the files of existing users.
- Invalid JSON in the user's file makes `fromJson` fail, and the apply fails for that file.
- `toPrettyJson` reformats the file and sorts its keys alphabetically (E2: `extensions` before `source`, `packages` before `theme`).
- It is more logic than a static file, and that logic needs tests.

### Option 4: artefiles owns only the package list; pi owns the package contents

**Description:** This option defines scope, not a write mechanism.
artefiles declares *which* packages. pi installs and updates *what is inside* them.

**Pros:** It splits the work along the line pi already draws: settings list the packages, and pi does the install and update.

**Cons:** It still needs a mechanism to write the list. Options 1–3 are the possible mechanisms.

**Why not chosen on its own:** It is the scope of the decision, not an alternative to option 3.

---

## Decision

**We will use option 3 within the scope of option 4.**
A `modify_` template merges the team package list into `~/.pi/agent/settings.json` as a union by source (E2).
It keeps every other key and every user package.
A user's object entry for a team source replaces the team's string.
artefiles owns only the list of package sources. pi installs and updates the contents.
The team list lives in `.chezmoidata/packages.yaml` under a `pi.packages` key, next to `vscode.extensions`.

---

## Consequences

### Positive Consequences
- Team package changes reach existing machines on the next `chezmoi update`, with no prompt and no apply failure.
- User preferences and packages that users install themselves survive.
- No new tool dependency: the template is pure chezmoi.

### Negative Consequences / Accepted Tradeoffs
- **Removing a package from the team list does not uninstall it.** It stays in existing files.
  Users run `pi remove <source>` themselves.
  A later change could record the team-managed entries in a separate key, so the merge can drop entries the team removed.
- **Users cannot opt out of a team package.** A `pi remove` of a team package comes back on the next apply.
  Changing this needs a user exclusion list; it is out of scope.
- Package contents are refreshed only when pi does it.
  A missing package is installed when pi starts.
  A newer npm version is installed only by `pi update --extensions` or `--all`.
  A bare `pi update` updates pi alone (E3).
- If a user's `settings.json` is not valid JSON, the apply fails for that file until the user fixes it.
- Package entries can be strings or objects (E3, pi's source).
  `uniq` removes only exact duplicates, so a user object that narrows a team source would appear next to the team string (E2).
  The template must therefore deduplicate by source, which costs more template logic than `uniq`.

### Risks
- pi could change the `packages` format or the path of `settings.json`. Revisit this ADR if the pi settings schema changes.
- If the team needs to remove packages from machines centrally, the union rule no longer works. Revisit when that first happens.

---

## Implementation Notes

The module is not implemented here; issue #253 tracks it. This is the contract it must meet.

- **File:** `dot_pi/agent/modify_settings.json`, with the `chezmoi:modify-template` marker.
  If pi is optional, gate it with a module in `select-modules.sh` and `.chezmoiignore`.
- **Target path:** the merge targets `~/.pi/agent/settings.json`. A user who points `PI_CODING_AGENT_DIR` elsewhere is out of scope.
- **Input:** the current file on `.chezmoi.stdin`. It can be empty or missing, or hold any valid JSON object.
- **Output:** the same object, where `packages` is, in this order:
  1. each team entry, replaced by the user's object entry with the same source when one exists, then
  2. the user's entries whose source is not a team source, in their original order.

  The source of an entry is the entry itself if it is a string, or its `.source` if it is an object.
  The replacement lets a user narrow a team package's resources.
  Every other key is unchanged.
  The union-by-source template in E2 meets this contract.
- **Invariants:** applying the template twice changes nothing. It never removes a key.
- **Failure:** invalid JSON in the input fails the apply with chezmoi's template error. The file is left untouched.
- **Package refresh (optional):** add a `run_onchange_after_` script, following `run_onchange_after_install-vscode-extensions.sh.tmpl`.
  It runs `pi update --extensions` when the team list changes and skips when `pi` is not on PATH.
  It is optional, because pi installs missing packages at start.
  It is still worth having, because it also brings npm packages that are already installed up to date.

**Tests the module needs** (bats, with stdin fixtures).
The existing `chezmoi_render` in `tests/helpers/setup.bash` cannot render this file.
It pipes the template itself on stdin, so `.chezmoi.stdin` would hold the template and not a fixture.
Add a helper `chezmoi_render_with_stdin H FILE FIXTURE`, with the same isolation as `chezmoi_render`:

```bash
XDG_CONFIG_HOME="$h/.config" HOME="$h" chezmoi execute-template --with-stdin \
  --config "$h/.config/chezmoi/chezmoi.toml" \
  --source "$REPO_ROOT" --destination "$h" \
  -f "$REPO_ROOT/$file" < "$fixture"
```

The tests:
1. Empty stdin gives exactly the team list.
2. A user file with extra keys and packages keeps them all and adds the team entries.
3. Idempotency: rendering the output again gives the same bytes.
4. A user object entry for a team source is kept once, and no duplicate string is added.
5. Invalid JSON on stdin makes the render exit non-zero.
6. The team list in the output equals `yq '.pi.packages[]' .chezmoidata/packages.yaml`.
7. The `run_onchange` script exits 0 and prints a skip message when `pi` is missing.

---

## Review Date

Review this decision when:
- the team first needs to remove a package from every machine, or
- pi changes its settings schema or settings path, or
- pi adds a native "managed settings" layer that artefiles could write without merging.
