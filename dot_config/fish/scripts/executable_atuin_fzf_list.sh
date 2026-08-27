#!/usr/bin/env bash
# Query atuin with context filtering; colors and layout mirror atuin's own
# TUI (see history_list.rs): relative time = Guidance/dark-blue, duration =
# AlertInfo/AlertError (green on success, red on failure) by h.success(),
# command = plain Base. No raw exit-code column - atuin doesn't show one
# either; the duration color already carries that signal.
#
# Records are NUL-separated (atuin --print0 / fzf --read0) so a command
# containing embedded newlines stays one record instead of exploding into
# stray rows; the display copy substitutes a visible glyph for newlines
# while the hidden raw copy (appended after a US byte) keeps them intact
# for exact reinsertion into the command line. Formatting is done in perl,
# not awk - macOS's /usr/bin/awk uses C strings internally and can't hold
# a NUL byte in ORS, which silently breaks NUL-delimited output.
set -uo pipefail

query="${1:-}"
filter_mode="${2:-directory}"
US=$'\x1f'
fmt="{exit}${US}{relativetime}${US}{duration}${US}{command}"

# atuin search exits 1 on zero matches (e.g. no results yet in this
# directory's history) - that's a valid "empty list" state for fzf's
# reload, not a failure, so don't let it abort the script.
atuin search --print0 --format "$fmt" --filter-mode "$filter_mode" -- "$query" 2>/dev/null \
  | perl -CO -0777 -ne '
      my $US = "\x1f";
      for my $rec (split /\0/, $_) {
        next if $rec eq "";
        my ($code, $t, $dur, @rest) = split /\Q$US\E/, $rec, -1;
        my $cmd = join $US, @rest;
        my $col = ($code eq "0") ? "32" : "31";
        (my $display = $cmd) =~ s/\n/\x{23ce} /g;
        print "\033[34m", sprintf("%6s", $t), "\033[0m  ",
              "\033[${col}m", sprintf("%5s", $dur), "\033[0m  ",
              $display, $US, $cmd, "\0";
      }
    '
exit 0
