function _fuzzy_complete_escape --description 'Escape a completion candidate for the command line or the picker query'
    # Usage: _fuzzy_complete_escape <candidate> <token>
    # <token> is the text being completed, without an opening quote. Prints
    # <candidate> backslash-escaped, with the '$' in the part the token typed
    # and a leading '~' the token typed left bare, so they still expand.
    # Pure: prints only.
    # Backslash escaping, never quotes: a quoted '~/dir/' or '$VAR' no longer
    # expands, and the next Tab finds nothing inside it. The part of the
    # candidate the user typed (fish matches it case-insensitively) keeps its
    # '$' bare, as fish's own Tab does; a '$' after it stays escaped, since a
    # file name can hold one.
    set -l typed ''
    set -l rest $argv[1]
    set -l n (string length -- "$argv[2]")
    if test $n -gt 0; and test (string lower -- (string sub -l $n -- $argv[1])) = (string lower -- $argv[2])
        set typed (string sub -l $n -- $argv[1])
        set rest (string sub -s (math $n + 1) -- $argv[1])
    end
    set -l escaped (string escape -n -- $typed | string replace -a '\\$' '$')(string escape -n -- $rest)
    # A leading '~' the user typed stays bare too, so it still expands.
    if string match -q '~*' -- $argv[2]
        set escaped (string replace -r '^\\\\~' '~' -- $escaped)
    end
    printf '%s\n' $escaped
end
