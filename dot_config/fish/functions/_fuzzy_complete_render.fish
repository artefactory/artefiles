function _fuzzy_complete_render --description 'Render complete -C candidates as fzf rows: candidate + dimmed description'
    set -l cmd_line $argv[1]
    set -l comps (complete -C $cmd_line)

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
