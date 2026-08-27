function fuzzy_complete --description 'Tab completion picker backed by fzf'
    set -l cmd_line (commandline -cp)
    set -l token (commandline -t)
    set -l command (commandline -co)[1]

    # A bare/empty command line completes to every command on PATH
    # (thousands of entries) - not worth rendering through fzf, and fish's
    # native pager handles that case fine on its own.
    if test -z (string trim -- $cmd_line)
        commandline -f complete
        return 0
    end

    # An unambiguous zoxide jump (see completions/cd.fish for the threshold)
    # skips the picker entirely - same target `cd <token><enter>` would
    # reach, just inserted rather than run, so a stray keystroke never lands
    # you somewhere you didn't mean to go.
    if test "$command" = cd
        and functions -q __zoxide_cd_dominant_match
        and set -l winner (__zoxide_cd_dominant_match $token)
        _fuzzy_complete_insert $winner
        return 0
    end

    set -l comps (complete -C $cmd_line)

    if test (count $comps) -eq 0
        commandline -f complete
        return 0
    end

    if test (count $comps) -eq 1
        _fuzzy_complete_insert (string split -f1 \t -- $comps[1])
        return 0
    end

    # Everything before the token being completed (e.g. "git " for "git c").
    # Exported so the reload binding below can rebuild "prefix + live query"
    # and re-run `complete -C` as the user edits the fzf search box, instead
    # of filtering a candidate list that was frozen at the old prefix.
    set -lx FC_PREFIX (string sub -l (math (string length -- $cmd_line) - (string length -- $token)) -- $cmd_line)

    # Layout/cycle/pointer/marker/etc come from the global FZF_DEFAULT_OPTS;
    # only pass what's specific to rendering completion candidates here.
    # --nth=1 restricts fzf's own live filtering to the candidate column
    # (not the description) - fzf can only search a field it also displays
    # (--nth cannot see a field --with-nth hides), so candidate and search
    # target must be the same untruncated text; no separate display-only
    # column. The initial list stays interactive while `change:reload` swaps
    # in the freshly `complete -C`'d candidates for the new prefix a beat
    # later - no frozen/blank list while that runs.
    # The reload is debounced with `sleep 0.1` (fzf cancels the previous
    # still-sleeping reload when a new keystroke arrives) so fast typing
    # doesn't spawn a `complete -C` call per character.
    set -l extra_opts
    if test "$command" = cd
        # zoxide (aliased to `cd`) already returns its own frecency-ranked,
        # token-filtered order (see completions/cd.fish) - that ranking IS
        # what a bare `cd <token>` jump resolves to. Without --no-sort, fzf
        # re-scores candidates with its own fuzzy heuristic and can promote
        # a lower-frecency dir (e.g. a literal prefix match) above it,
        # silently diverging from what typing `cd <token><enter>` would do.
        set extra_opts --no-sort
    end

    set -l chosen (_fuzzy_complete_render $cmd_line \
        | fzf --ansi --tiebreak=begin $extra_opts \
              --delimiter='\t' --with-nth=1,2 --nth=1 \
              --with-shell='fish -c' \
              --bind='change:reload:sleep 0.1; _fuzzy_complete_render "$FC_PREFIX"{q}' \
              --bind='tab:down,shift-tab:up' \
              --query="$token" \
              --prompt="$command> " --header='enter: insert  esc: cancel')

    if test -n "$chosen"
        _fuzzy_complete_insert (string split -f1 \t -- $chosen)
    else
        commandline -f repaint
    end
end
