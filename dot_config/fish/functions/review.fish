function review --description 'Review code with tuicr: working tree, a file, a branch, a commit, or a PR'
    set -l sub $argv[1]

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
            tuicr -r "$base..HEAD"

        case commit
            set -l rev HEAD~..HEAD
            test -n "$argv[2]"; and set rev "$argv[2]~..$argv[2]"
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
