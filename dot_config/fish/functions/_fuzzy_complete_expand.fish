function _fuzzy_complete_expand --description 'Expand a leading ~ or $VAR in a completion candidate'
    # Usage: _fuzzy_complete_expand <candidate>
    # `complete -C` returns '~/x' and '$HOME/x' unexpanded, so path tests on
    # the raw candidate fail. Expands a leading '~' (not '~user') and one
    # leading '$NAME' from this shell's variables; an unset variable expands
    # to the empty string. Prints the result; never evaluates anything else.
    set -l path (string replace -r -- '^~(?=/|$)' $HOME $argv[1])
    set -l m (string match -rg -- '^\$(\w+)(.*)$' $path)
    if test (count $m) -eq 2
        set -l name $m[1]
        set path "$$name"$m[2]
    end
    printf '%s\n' $path
end
