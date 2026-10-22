function _fuzzy_complete_insert --description 'Replace the current token with a chosen candidate, matching native fish escaping and trailing-space rules'
    set -l cand $argv[1]
    # The token as the picker matched it, without an opening quote. Falls
    # back to the command line so the function stays callable on its own.
    set -l token $argv[2]
    if not set -q argv[2]
        set token (string replace -r '^[\'"]' '' -- (commandline -t))
    end

    # fish appends a space after an unambiguous completion so the next arg
    # can be typed immediately, except when the candidate ends in '/' or '='
    # (a directory or a flag=value form), since those invite continuing the
    # same token rather than starting a new one. Decided on the raw
    # candidate, before escaping it for the command line.
    set -l suffix ' '
    set -l last_char (string sub -s -1 -- $cand)
    if test "$last_char" = / -o "$last_char" = =
        set suffix ''
    end

    # Backslash escaping, never quotes: a quoted '~/dir/' or '$VAR' no longer
    # expands, and the next Tab finds nothing inside it. The part of the
    # candidate the user typed (fish matches it case-insensitively) keeps its
    # '$' bare, as fish's own Tab does; a '$' after it stays escaped, since a
    # file name can hold one.
    set -l typed ''
    set -l rest $cand
    set -l n (string length -- "$token")
    if test $n -gt 0; and test (string lower -- (string sub -l $n -- $cand)) = (string lower -- $token)
        set typed (string sub -l $n -- $cand)
        set rest (string sub -s (math $n + 1) -- $cand)
    end
    set -l escaped (string escape -n -- $typed | string replace -a '\\$' '$')(string escape -n -- $rest)
    # A leading '~' the user typed stays bare too, so it still expands.
    if string match -q '~*' -- $token
        set escaped (string replace -r '^\\\\~' '~' -- $escaped)
    end

    # The whole token is replaced, as fish's own Tab does, and the cursor
    # lands right after the inserted candidate.
    set -l start (math (commandline -C) - (string length -- (commandline -ct)))
    commandline -t -- "$escaped$suffix"
    commandline -C (math $start + (string length -- "$escaped$suffix"))
    commandline -f repaint
end
