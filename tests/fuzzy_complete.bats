#!/usr/bin/env bats
# The fzf Tab picker inserts what fish's own Tab would: backslash-escaped, with
# a typed ~ and $ left bare, the whole word replaced, and globs left to fish. A stub commandline holds the buffer; fzf is a stub that picks a row.

setup() {
  load 'helpers/setup'
  command -v fish > /dev/null || skip "fish is not installed"
  H="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/h"
  W="$H/work"
  mkdir -p "$W" "$H/Documents"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  LOG="$BATS_TEST_TMPDIR/log"
  : > "$LOG"
  # fzf stub: logs its arguments, prints the row whose candidate is $FZF_PICK.
  cat > "$BIN/fzf" << 'EOF'
#!/bin/sh
printf 'FZF:' >> "$LOG"; printf ' [%s]' "$@" >> "$LOG"; echo >> "$LOG"
awk -F '\t' -v pick="$FZF_PICK" '$1 == pick { print; exit }'
EOF
  chmod +x "$BIN/fzf"
  # commandline stub over $__buf, $__cur (cursor) and $__start (where the
  # current token starts); a token ends at the next space after the cursor.
  STUB="$BATS_TEST_TMPDIR/stub.fish"
  cat > "$STUB" << 'EOF'
function __tok_end
    set -l rest (string sub -s (math $__cur + 1) -- "$__buf")
    set -l word (string match -r '^[^ ]*' -- "$rest")
    math $__cur + (string length -- "$word")
end
function commandline
    argparse c p t o C f -- $argv
    if set -q _flag_f
        echo "FUNC: $argv" >> $LOG
    else if set -q _flag_C
        if set -q argv[1]
            set -g __cur $argv[1]
        else
            echo $__cur
        end
    else if set -q _flag_o
        string split ' ' -- (string sub -l $__cur -- "$__buf")
    else if set -q _flag_p
        string sub -l $__cur -- "$__buf"
    else if set -q _flag_c
        string sub -s (math $__start + 1) -l (math $__cur - $__start) -- "$__buf"
    else if set -q argv[1]
        set -g __buf (string sub -l $__start -- "$__buf")"$argv[1]"(string sub -s (math (__tok_end) + 1) -- "$__buf")
    else
        string sub -s (math $__start + 1) -l (math (__tok_end) - $__start) -- "$__buf"
    end
end
EOF
}

# tab LINE [CURSOR [START]] — press Tab on LINE with the cursor at CURSOR
# (default: the end) in a token starting at START (default: after the last
# space before the cursor); prints the buffer and cursor after.
tab() {
  local line="$1" cur="${2:-${#1}}"
  local before="${line:0:$cur}"
  local last="${before##* }"
  local start="${3:-$((${#before} - ${#last}))}"
  run env -i HOME="$H" PATH="$BIN:/usr/bin:/bin" LOG="$LOG" FZF_PICK="${FZF_PICK:-}" \
    "$(command -v fish)" --no-config -c "
      cd $W
      set fish_function_path $REPO_ROOT/dot_config/fish/functions \$fish_function_path
      source $STUB
      set -g __buf '$line'
      set -g __cur $cur
      set -g __start $start
      complete -c mycmd -f -a '(echo call >> \$LOG; printf \"%s\n\" alpha alpine \"!bang\" \"!boom\")'
      fuzzy_complete
      cat \$LOG; echo \"BUF=[\$__buf] CUR=\$__cur\""
}

@test "a typed ~ stays bare, so the path still expands and completes" {
  tab 'ls ~/Doc'
  [[ "$output" == *"BUF=[ls ~/Documents/] CUR=15"* ]]
}

@test "a typed \$ stays bare, a space in the candidate is backslash-escaped" {
  mkdir "$H/My Docs"
  tab 'ls $HOME/My'
  [[ "$output" == *'BUF=[ls $HOME/My\ Docs/]'* ]]
}

@test "a \$ in the part of the candidate the user did not type stays escaped" {
  touch "$H/a\$b.txt"
  tab 'ls $HOME/a'
  [[ "$output" == *'BUF=[ls $HOME/a\$b.txt ]'* ]]
}

@test "a token opened with a quote queries fzf without the quote and inserts unquoted" {
  mkdir "$W/My Docs" "$W/My Data"
  FZF_PICK='My Data/' tab 'ls "My D' 8 3
  grep -qF -- '[--query=My D]' "$LOG"
  [[ "$output" == *'BUF=[ls My\ Data/]'* ]]
}

# complete -C returns a glob that matches files as the token itself.
@test "a glob is handed to fish's own completion, not inserted as an escaped literal" {
  touch "$W/scratch_a" "$W/scratch_b"
  tab 'ls scratch_*'
  grep -qx 'FUNC: complete' "$LOG"
  [[ "$output" == *'BUF=[ls scratch_*]'* ]]
}

# fish's own Tab, checked in a terminal: `ls Doc|s` gives `ls Documents/`, and
# `ls Docu|xyz` (no match) changes nothing.
@test "Tab inside a word completes the whole word and replaces it, as fish's own Tab does" {
  mkdir "$W/Documents"
  tab 'ls Docs' 6
  [[ "$output" != *"Invalid length"* ]]
  [[ "$output" == *"BUF=[ls Documents/] CUR=13"* ]]
  tab 'ls Docuxyz' 7
  grep -qx 'FUNC: complete' "$LOG"
  [[ "$output" == *"BUF=[ls Docuxyz] CUR=7"* ]]
}

@test "the picker runs complete -C once per Tab" {
  FZF_PICK=alpine tab 'mycmd al'
  [ "$(grep -c '^call$' "$LOG")" -eq 1 ]
  [[ "$output" == *'BUF=[mycmd alpine ]'* ]]
}

@test "a token fzf would read as a search operator is matched as typed" {
  FZF_PICK='!bang' tab 'mycmd !'
  grep -qF -- '[--no-extended]' "$LOG"
  : > "$LOG"
  FZF_PICK=alpha tab 'mycmd a'
  ! grep -qF -- '[--no-extended]' "$LOG"
}
