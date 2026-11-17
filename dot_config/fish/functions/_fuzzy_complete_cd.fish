function _fuzzy_complete_cd --description 'List cd candidates: local directories, then zoxide entries'
    # Usage: _fuzzy_complete_cd [--self] [--] <prefix> <token>
    # <prefix> is the command line before <token> (e.g. `cd `); <token> the
    # raw token. Prints `complete -C`-style rows (candidate, optional tab
    # and description):
    # - a token holding a wildcard: _fuzzy_complete_glob --any --dirs;
    # - else fish's own directory completions for the line, without the
    #   zoxide rows completions/cd.fish adds (fish shows those only when no
    #   local directory matches), followed by `zoxide query -l` for the
    #   token in frecency order, minus directories already listed.
    #   zoxide is skipped for a path token: one starting with '/', '~', '.'
    #   or '$', or ending in '/'.
    # --self: when the token names an existing directory and ends in '/',
    # print it first, so the picker can accept the directory it browses
    # into, even one without subdirectories.
    # Reads the filesystem and the zoxide database; no side effects.
    argparse self -- $argv; or return 2
    set -l prefix $argv[1]
    set -l token $argv[2]

    if set -l rows (_fuzzy_complete_glob --any --dirs -- $token)
        test (count $rows) -gt 0; and printf '%s\n' $rows
        return 0
    end

    set -l plain (string unescape -- $token)
    if set -q _flag_self
        and string match -q -- '*/' $plain
        and test -d (_fuzzy_complete_expand $plain)
        echo $plain
    end

    set -l local (complete -C "$prefix$token" | string match -v -- '*'\t'zoxide')
    test (count $local) -gt 0; and printf '%s\n' $local

    command -q zoxide; or return 0
    string match -qr -- '^[/~.$]|/$' $plain; and return 0

    # The same directory can be spelled with or without symlinks resolved.
    set -l seen
    for row in $local
        set -l p (string replace -r -- '/$' '' (_fuzzy_complete_expand (string split -f1 \t -- $row)))
        set -a seen (path normalize -- $PWD/$p) (path resolve -- $p)
    end
    set -l query
    test -n "$plain"; and set query -- $plain
    for z in (zoxide query -l $query 2>/dev/null)
        contains -- $z $seen; and continue
        printf '%s\tzoxide\n' $z
    end
    return 0
end
