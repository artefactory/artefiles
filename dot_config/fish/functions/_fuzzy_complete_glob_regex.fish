function _fuzzy_complete_glob_regex --description 'Translate a path glob into an anchored PCRE matching relative paths'
    # Usage: _fuzzy_complete_glob_regex <pattern>
    # Prints one regex, anchored at both ends, for paths without a trailing
    # '/'. '**/' matches zero or more whole directories, a trailing '**'
    # anything, '*' any run inside a segment, and '?' one character inside
    # a segment unless fish's qmark-noglob feature makes it literal. Every
    # other character is literal. The last segment is a prefix: an implicit
    # '*' follows the pattern, so a partly typed name still matches; after a
    # trailing '/' it must match at least one character.
    # Reads the qmark-noglob feature flag; prints only.
    set -l re (string escape --style=regex -- $argv[1])
    # Escaped forms: '**' arrives as '\*\*', '*' as '\*', '?' as '\?'.
    set re (string replace -a -- '\*\*/' '(?:.*/)?' $re)
    set re (string replace -a -- '\*\*' '.*' $re)
    set re (string replace -a -- '\*' '[^/]*' $re)
    if not status test-feature qmark-noglob
        set re (string replace -a -- '\?' '[^/]' $re)
    end
    # After a trailing '/' the prefix must be non-empty: 'sub/' lists the
    # children of sub, not sub itself.
    set -l last '[^/]*'
    string match -q -- '*/' $argv[1]; and set last '[^/]+'
    printf '^%s%s$\n' $re $last
end
