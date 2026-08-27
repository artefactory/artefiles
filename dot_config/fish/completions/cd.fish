if type -q zoxide
    function __zoxide_cd_complete
        set -l token (commandline -ct)
        if test -z "$token"
            zoxide query -l
        else
            zoxide query -l -- $token
        end
    end
    complete -c cd -k -a '(__zoxide_cd_complete)' -d 'zoxide'

    # Print the top zoxide match for $argv[1] iff it dominates the runner-up,
    # else print nothing and fail. Lets fuzzy_complete skip the fzf picker
    # for an unambiguous jump (same target `cd <token><enter>` would reach)
    # while still just inserting text, never auto-running the command.
    # Both an absolute score floor and a margin over the runner-up are
    # required: either alone admits a false positive (a big ratio between
    # two noise-level scores, or a big score with a close runner-up).
    function __zoxide_cd_dominant_match
        set -l token $argv[1]
        test -n "$token"; or return 1

        set -l scored (zoxide query -l -s -- $token 2>/dev/null)
        test (count $scored) -gt 0; or return 1

        set -l top (string match -rg '^\s*(\S+)\s+(.*)$' -- $scored[1])
        if test (count $scored) -eq 1
            echo $top[2]
            return 0
        end

        set -l second (string match -rg '^\s*(\S+)\s+(.*)$' -- $scored[2])
        # fish's `test` only compares integers, and `math` has no
        # comparison operators - scale both scores by 10x (truncated to an
        # integer via --scale=0) so `test -ge` can compare them directly
        # while keeping one decimal place of precision.
        set -l top_i (math --scale=0 -- "$top[1] * 10")
        set -l second_i (math --scale=0 -- "$second[1] * 10")
        if test $top_i -ge 100
            and test $top_i -ge (math --scale=0 -- "6 * $second_i")
            echo $top[2]
            return 0
        end
        return 1
    end
end
