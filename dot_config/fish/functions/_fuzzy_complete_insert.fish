function _fuzzy_complete_insert --description 'Replace the current token with a chosen candidate, matching native fish trailing-space rules'
    set -l cand $argv[1]

    # fish appends a space after an unambiguous completion so the next arg
    # can be typed immediately, except when the candidate ends in '/' or '='
    # (a directory or a flag=value form), since those invite continuing the
    # same token rather than starting a new one. Decided on the raw
    # candidate, before escaping quotes/spaces for the command line.
    set -l suffix ' '
    set -l last_char (string sub -s -1 -- $cand)
    if test "$last_char" = / -o "$last_char" = =
        set suffix ''
    end

    commandline -t -- (string escape -- $cand)$suffix
    commandline -f repaint
end
