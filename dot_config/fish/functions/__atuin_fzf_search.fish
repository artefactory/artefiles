function __atuin_fzf_search --description 'atuin history search rendered through fzf'
    set -l filter_mode $argv[1]
    if test -z "$filter_mode"
        set filter_mode directory
    end

    set -l us \x1f
    set -l script "$HOME/.config/fish/scripts/atuin_fzf_list.sh"
    set -l initial_query (commandline -b)

    set -l selection (fzf --disabled --ansi --tac --no-sort --read0 --print0 --no-multi-line \
        --delimiter "$us" --with-nth=1 \
        --header "atuin: $filter_mode" \
        --query "$initial_query" \
        --bind "start:reload:$script {q} $filter_mode" \
        --bind "change:reload:$script {q} $filter_mode" < /dev/null | string split0)

    if test -n "$selection"
        set -l fields (string split "$us" -- $selection)
        commandline -r -- $fields[-1]
    end
    commandline -f repaint
end
