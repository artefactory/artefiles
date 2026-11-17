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

    set -l escaped (_fuzzy_complete_escape $cand $token)

    # The whole token is replaced, as fish's own Tab does, and the cursor
    # lands right after the inserted candidate.
    set -l start (math (commandline -C) - (string length -- (commandline -ct)))
    commandline -t -- "$escaped$suffix"
    commandline -C (math $start + (string length -- "$escaped$suffix"))
    commandline -f repaint
end
