function fuzzy_complete --description 'Tab completion picker backed by fzf'
    # Like fish's own Tab, the whole token is completed, the text after the
    # cursor included (`Doc|s` completes to `Documents/`), and the whole
    # token is replaced. $cmd_line therefore runs to the end of the token.
    set -l raw_token (commandline -t)
    set -l cmd_line (commandline -cp)(string sub -s (math (string length -- (commandline -ct)) + 1) -- $raw_token)
    set -l command (commandline -co)[1]

    # A token opened with a quote keeps it in `commandline -ct`, while
    # `complete -C` returns candidates unquoted, so fzf's --query would never
    # match. The quote is dropped for matching only: $cmd_line still has it,
    # so `complete -C` sees the real quoting context.
    set -l token (string replace -r '^[\'"]' '' -- $raw_token)

    # A bare/empty command line completes to every command on PATH
    # (thousands of entries) - not worth rendering through fzf, and fish's
    # native pager handles that case fine on its own.
    if test -z (string trim -- $cmd_line)
        commandline -f complete
        return 0
    end

    # Everything before the token being completed (e.g. "git " for "git c").
    # Exported so the reload binding below can rebuild "prefix + live query"
    # and re-run `complete -C` as the user edits the fzf search box, instead
    # of filtering a candidate list that was frozen at the old prefix.
    # It keeps an opening quote, since {q} carries the token without it.
    set -lx FC_PREFIX (string sub -l (math (string length -- $cmd_line) - (string length -- $token)) -- $cmd_line)

    # `cd` lists local directories, then zoxide entries (_fuzzy_complete_cd):
    # one row in total is inserted, more open the picker. Tab never jumps
    # to a zoxide guess on its own; `cd <token><enter>` still does.
    # Elsewhere, `complete -C` returns nothing for a `**` token whose last
    # segment is literal (`src/**/sub/fi`), so _fuzzy_complete_glob lists
    # those. A wildcard in the last segment (`src/**/*.py`) stays with
    # fish's own Tab below, which expands it in place to every match.
    set -l comps
    if test "$command" = cd
        set comps (_fuzzy_complete_cd -- $FC_PREFIX $token)
    else if not set comps (_fuzzy_complete_glob -- $token)
        set comps (complete -C $cmd_line)
    end

    if test (count $comps) -eq 0
        commandline -f complete
        return 0
    end

    if test (count $comps) -eq 1
        set -l cand (string split -f1 \t -- $comps[1])
        # `complete -C` does no glob expansion: for `scratch_*` it returns the
        # token itself, and inserting it escaped would turn the glob into a
        # dead literal. Fish's own reader handles that case.
        if test "$cand" = "$token"
            commandline -f complete
            return 0
        end
        _fuzzy_complete_insert $cand $token
        return 0
    end

    # Layout/cycle/pointer/marker/etc come from the global FZF_DEFAULT_OPTS;
    # only pass what's specific to rendering completion candidates here.
    # --nth=1 restricts fzf's own live filtering to the candidate column
    # (not the description) - fzf can only search a field it also displays
    # (--nth cannot see a field --with-nth hides), so candidate and search
    # target must be the same untruncated text; no separate display-only
    # column. The initial list stays interactive while `change:reload` swaps
    # in the freshly `complete -C`'d candidates for the new prefix a beat
    # later - no frozen/blank list while that runs.
    # Tab grows the query to the next path segment of the highlighted row
    # (after `cd`, to the whole row, whose subdirectories the reload then
    # lists under it) and Shift-Tab drops one (_fuzzy_complete_extend);
    # arrows and ctrl-n/ctrl-p move through the list. The new query fires
    # the same change reload. Both also move the cursor to the first row,
    # which the reload keeps: fzf would keep the old index instead, so Enter
    # after Tab could pick a subdirectory over the directory Tab chose.
    # The reload is debounced with `sleep 0.1` (fzf cancels the previous
    # still-sleeping reload when a new keystroke arrives) so fast typing
    # doesn't spawn a `complete -C` call per character.
    set -l extra_opts
    # fzf reads a term starting with ! ' or ^, or ending with $, as a search
    # operator; a token shaped like that must be matched as typed.
    if string match -qr '^[!\'^]|\$$' -- $token
        set -a extra_opts --no-extended
    end
    set -l extend_opts
    if test "$command" = cd
        # The rows come ordered: the browsed directory, local directories,
        # then zoxide by frecency. Without --no-sort, fzf re-scores them
        # with its own fuzzy heuristic and the order is lost. fish and
        # zoxide match directories case-insensitively; fzf's smart case
        # would hide `work/...` rows for the query `Wo`.
        set -a extra_opts --no-sort -i
        set extend_opts --whole
    end
    # fzf's search is off for queries it cannot match literally (see
    # _fuzzy_complete_search_mode); the reload filters those instead. The
    # change binding re-decides on every edit, before the reload. It runs in
    # the foreground: a bg-transform can land after a later keystroke's and
    # leave search on for a glob.
    if test (_fuzzy_complete_search_mode $token) = disable-search
        set -a extra_opts --disabled
    end

    # Every reload, search toggle and Tab starts a fish of its own. A bare
    # `fish --no-config` given this shell's function and completion search
    # paths yields the same candidates as a configured fish in about half
    # the time, since config.fish and conf.d are skipped; that matters for
    # the search toggle, which runs on every keystroke. Names ending in PATH
    # are exported colon-joined and re-imported as lists.
    set -lx FC_FUNCTION_PATH $fish_function_path
    set -lx FC_COMPLETE_PATH $fish_complete_path
    set -l fc_env 'set fish_function_path $FC_FUNCTION_PATH; set fish_complete_path $FC_COMPLETE_PATH;'

    # The first list reuses $comps: `complete -C` runs again only on reload,
    # so a slow completion script is not paid for twice per Tab.
    set -l chosen (printf '%s\n' $comps | _fuzzy_complete_render \
        | fzf --ansi --tiebreak=begin $extra_opts \
              --delimiter='\t' --with-nth=1,2 --nth=1 \
              --with-shell='fish --no-config -c' \
              --bind="change:transform($fc_env _fuzzy_complete_search_mode {q})+reload(sleep 0.1; $fc_env _fuzzy_complete_render --split \"\$FC_PREFIX\" {q})" \
              --bind="tab:transform-query($fc_env _fuzzy_complete_extend $extend_opts {q} {1})+first" \
              --bind="shift-tab:transform-query($fc_env _fuzzy_complete_extend --back {q})+first" \
              --query="$token" \
              --prompt="$command> " --header='tab: extend  shift-tab: back  enter: insert  esc: cancel')

    if test -n "$chosen"
        _fuzzy_complete_insert (string split -f1 \t -- $chosen) $token
    else
        commandline -f repaint
    end
end
