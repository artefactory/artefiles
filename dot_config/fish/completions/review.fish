# Completions for the `review` function (see functions/review.fish). This is
# what makes the fzf Tab picker (see functions/fuzzy_complete.fish) useful for
# `review`: it must be a real file on $fish_complete_path, since
# fuzzy_complete's change:reload re-runs `complete -C` in a fresh
# non-interactive `fish -c` that only sees files on disk, never anything only
# sourced into the interactive session.

complete -c review -f -n '__fish_use_subcommand' -a file -d 'review one file or directory'
complete -c review -f -n '__fish_use_subcommand' -a branch -d 'review this branch/chain against main'
complete -c review -f -n '__fish_use_subcommand' -a commit -d 'review the last commit'
complete -c review -f -n '__fish_use_subcommand' -a pr -d 'review a GitHub pull request'
complete -c review -f -n '__fish_use_subcommand' -a list -d 'list persisted review sessions'
complete -c review -f -n '__fish_use_subcommand' -a comments -d 'print comments from a session'

# `review file <path>` completes actual paths.
complete -c review -F -n "__fish_seen_subcommand_from file"

# `review pr <n>` completes open PR numbers when gh is available.
complete -c review -f -n "__fish_seen_subcommand_from pr" -a '(
    type -q gh
    and gh pr list --state open --json number,title \
        --jq ".[] | \"\(.number)\t\(.title)\"" 2>/dev/null
)'

# `review branch <base>` completes candidate trunk bookmarks/branches.
complete -c review -f -n "__fish_seen_subcommand_from branch" -a '(
    if type -q jj; and jj root >/dev/null 2>&1
        jj bookmark list --no-pager -T "name ++ \"\n\"" 2>/dev/null
    else if type -q git
        git for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null
    end
)'
