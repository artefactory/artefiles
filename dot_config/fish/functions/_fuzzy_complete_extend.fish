function _fuzzy_complete_extend --description 'Grow or shrink the picker query by one path segment'
    # Usage: _fuzzy_complete_extend <query> <candidate>
    #        _fuzzy_complete_extend --whole <query> <candidate>
    #        _fuzzy_complete_extend --back <query>
    # <query> is the picker's raw query (escaped as on the command line);
    # <candidate> the highlighted candidate, unescaped as `complete -C`
    # prints it. Prints the new query, escaped the same way:
    # - a `**` query: the shortest run of the candidate's leading segments
    #   the glob matches, plus the next '/' (so `a/**/su` over
    #   `a/b c/sub/x.py` gives `a/b\ c/sub/`);
    # - any other query: the candidate cut at the first '/' after the part
    #   it shares with the query, or the whole candidate when none follows.
    # --whole: the whole candidate, with a trailing '/' (the `cd` picker,
    # whose rows are all directories, zoxide's absolute ones included).
    # An empty candidate leaves the query unchanged.
    # --back: the query minus its last segment (`a/b/c` and `a/b/c/` give
    # `a/b/`). A `**` replaced by an extension is not restored.
    # Pure: prints only.
    argparse back whole -- $argv; or return 2
    set -l query $argv[1]

    if set -q _flag_back
        string replace -r -- '[^/]*/?$' '' $query
        return 0
    end

    set -l cand $argv[2]
    if test -z "$cand"
        printf '%s\n' $query
        return 0
    end

    if set -q _flag_whole
        string match -q -- '*/' $cand; or set cand $cand/
        _fuzzy_complete_escape $cand $query
        return 0
    end

    set -l plain (string unescape -- $query)
    # Segments of the candidate, each but the last carrying its '/'.
    set -l segs (string match -ar -- '[^/]*/|[^/]+$' $cand)
    set -l out
    if _fuzzy_complete_glob --is-glob -- $query
        set -l re (_fuzzy_complete_glob_regex $plain)
        set -l acc ''
        for s in $segs
            set acc $acc$s
            if string match -qr -- $re (string replace -r -- '/$' '' $acc)
                set out $acc
                break
            end
        end
        # No prefix matches (stale highlight during a reload): keep it.
        if test -z "$out"
            printf '%s\n' $query
            return 0
        end
    else
        # Length of the prefix shared with the query, then up to the next '/'.
        set -l n 0
        set -l max (math min (string length -- $plain), (string length -- $cand))
        while test $n -lt $max
            and test (string sub -s (math $n + 1) -l 1 -- $plain) = (string sub -s (math $n + 1) -l 1 -- $cand)
            set n (math $n + 1)
        end
        set -l acc ''
        for s in $segs
            set acc $acc$s
            if test (string length -- $acc) -gt $n
                break
            end
        end
        set out $acc
    end
    _fuzzy_complete_escape $out $query
end
