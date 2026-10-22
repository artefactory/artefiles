# _fuzzy_complete_render [CMDLINE] — the `complete -C CMDLINE` candidates as
# fzf rows. Without CMDLINE, the candidate lines are read from stdin.
function _fuzzy_complete_render --description 'Render complete -C candidates as fzf rows: candidate + dimmed description'
    set -l comps
    if set -q argv[1]
        set comps (complete -C $argv[1])
    else
        # A command substitution does not read the function's stdin.
        while read -l line
            set -a comps $line
        end
    end

    if test (count $comps) -eq 0
        return 0
    end

    set -l cands (string replace -r '\t.*$' '' -- $comps)
    set -l descs (string replace -r '^[^\t]*\t?' '' -- $comps)

    # No manual truncation/padding here: fzf can only search fields it also
    # displays (--nth cannot see a field hidden by --with-nth), so pre-cutting
    # the candidate for column alignment would silently hide real matches
    # whenever the query text falls in the cut portion. fzf truncates long
    # lines itself at render time without touching the underlying searchable
    # text, so overflow is left to it.
    for i in (seq (count $comps))
        printf '%s\t\x1b[2m%s\x1b[0m\n' $cands[$i] $descs[$i]
    end
end
