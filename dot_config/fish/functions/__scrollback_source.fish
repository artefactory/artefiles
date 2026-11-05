function __scrollback_source --description "Print the multiplexer that holds this shell's output: herdr or tmux"
    # HERDR_PANE_ID, not HERDR_ENV: a herdr popup sets HERDR_ENV without a pane
    # id, and pane read needs the id.
    if set -q HERDR_PANE_ID; and command -q herdr
        echo herdr
    else if set -q TMUX; and command -q tmux
        echo tmux
    else
        return 1
    end
end
