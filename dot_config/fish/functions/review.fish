function review --description 'Review code with tuicr: working tree, a file, a branch, a commit, or a PR'
    set -l sub $argv[1]

    # jj and git use different revset syntax for the same intent, so backend
    # detection lives in one place here rather than being duplicated per
    # subcommand. `jj root` only succeeds inside a jj-managed working copy,
    # including one colocated with git.
    set -l is_jj 0
    if type -q jj; and jj root >/dev/null 2>&1
        set is_jj 1
    end

    switch "$sub"
        case ''
            tuicr -w

        case file
            if test (count $argv) -lt 2
                echo "usage: review file <path>" >&2
                return 1
            end
            tuicr -w -p $argv[2..]

        case branch
            set -l base main
            test -n "$argv[2]"; and set base $argv[2]
            if test $is_jj -eq 1
                tuicr -r "$base..@"
            else
                tuicr -r "$base..HEAD"
            end

        case commit
            set -l rev
            if test $is_jj -eq 1
                set rev @-
                test -n "$argv[2]"; and set rev $argv[2]
            else
                set rev HEAD~..HEAD
                test -n "$argv[2]"; and set rev "$argv[2]~..$argv[2]"
            end
            tuicr -r "$rev"

        case pr
            tuicr pr $argv[2..]

        case list
            tuicr review list

        case comments
            tuicr review comments

        case '*'
            # Passthrough: keeps every raw tuicr flag (--help, -A, --theme, ...)
            # reachable without this wrapper tracking upstream's flag set.
            tuicr $argv
    end
end
