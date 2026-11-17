function _fuzzy_complete_glob --description 'List the paths a ** completion token matches'
    # Usage: _fuzzy_complete_glob [--dirs] [--any] [--is-glob] [--] <token>
    # <token> is the raw command-line token (backslash escapes allowed).
    # Handles only tokens holding '**' whose last segment has no wildcard;
    # returns 1 with no output for any other token, so the caller can fall
    # back to `complete -C` and fish's native Tab (which expands a wildcard
    # in the last segment in place, every match at once). Also returns 1
    # when fd is not installed.
    # --any: handle every token holding a wildcard, the last segment's
    # included (inside the picker there is no native Tab to expand it).
    # --is-glob: return 0 or 1 as above and print nothing.
    # Otherwise prints one candidate per line, in the form `complete -C`
    # uses: the directory part before the first wildcard kept as typed
    # (unescaped, '~' and '$VAR' left unexpanded), then the matched path,
    # with a trailing '/' on directories. Paths come from fd, so hidden and
    # gitignored ones are skipped; they are sorted bytewise.
    # --dirs: directories only, followed by the zoxide entries the whole
    # token matches (anywhere from a path component on, case-insensitively,
    # in frecency order), minus those already listed.
    # Reads the filesystem and the zoxide database; no side effects.
    argparse dirs any is-glob -- $argv; or return 2
    set -l token (string unescape -- $argv[1])
    # '?' is a wildcard only while fish's qmark-noglob feature is off.
    set -l wild '[*]'
    status test-feature qmark-noglob; or set wild '[*?]'

    if set -q _flag_any
        string match -qr -- $wild $token; or return 1
    else
        string match -q -- '*\*\**' $token; or return 1
        string match -qr -- $wild (string replace -r -- '^.*/' '' $token); and return 1
    end
    set -q _flag_is_glob; and return 0
    # fd ships with the shell_tools module; without it, leave the token to
    # `complete -C` and fish's own Tab.
    command -q fd; or return 1

    # Split at the first segment holding a wildcard: the part before it is
    # a literal directory fd starts from, the rest becomes the regex.
    set -l segs (string split -- / $token)
    set -l i 1
    while not string match -qr -- $wild $segs[$i]
        set i (math $i + 1)
    end
    set -l base ''
    if test $i -gt 1
        set base (string join -- / $segs[1..(math $i - 1)])/
    end
    set -l re (_fuzzy_complete_glob_regex (string join -- / $segs[$i..]))
    # fd prints directories with a trailing '/'; let the regex accept it.
    set -l line_re (string replace -r -- '\$$' '/?\$' $re)

    set -l root (_fuzzy_complete_expand $base)
    test -n "$root"; or set root .
    set -l found
    if test -d "$root"
        set -l types
        set -q _flag_dirs; and set types -t d
        # --no-require-git: honour .gitignore in jj repos without a .git.
        set -l hits (fd --base-directory $root --color never --no-require-git $types 2>/dev/null \
            | string match -r -- $line_re | LC_ALL=C sort)
        set found $base$hits
    end
    test (count $found) -gt 0; and printf '%s\n' $found

    set -q _flag_dirs; or return 0
    command -q zoxide; or return 0

    # Match zoxide's absolute paths against the whole token: from the root
    # when it is absolute after expansion, else from any path component.
    # The regex must span the whole entry: `string match -r` prints only
    # the matched part.
    set -l whole (_fuzzy_complete_expand $base)(string join -- / $segs[$i..])
    set -l zre (_fuzzy_complete_glob_regex $whole)
    if not string match -q -- '/*' $whole
        set zre (string replace -r -- '^\^' '^(?:.*/)?' $zre)
    end
    # The same directory can be spelled with or without symlinks resolved.
    set -l seen
    for f in $found
        set -l p (string replace -r -- '/$' '' (_fuzzy_complete_expand $f))
        set -a seen (path normalize -- $PWD/$p) (path resolve -- $p)
        string match -q -- '/*' $p; and set -a seen (path normalize -- $p)
    end
    for z in (zoxide query -l 2>/dev/null | string match -ri -- $zre)
        contains -- $z $seen; and continue
        echo $z
    end
    return 0
end
