function scrollback --description "Open this terminal's output in \$EDITOR, read from herdr or tmux"
    set -l capture
    switch "$(__scrollback_source)"
        case herdr
            set -q scrollback_lines; or set -l scrollback_lines 10000
            # recent-unwrapped: a long line comes back whole, not cut at the pane width.
            set capture herdr pane read $HERDR_PANE_ID --source recent-unwrapped --lines $scrollback_lines
        case tmux
            # -J joins wrapped lines; -S - starts at the top of the history.
            set capture tmux capture-pane -p -J -S -
            set -q TMUX_PANE; and set -a capture -t $TMUX_PANE
        case '*'
            echo "scrollback: no source here; run the shell inside herdr or tmux, or pipe a command into e (cmd | e)" >&2
            return 1
    end
    # The whole read finishes before the editor opens, so a failed read leaves
    # its own error on stderr instead of an empty file in the editor.
    set -l output ($capture | string collect)
    set -l rc $pipestatus[1]
    test $rc -eq 0; or return $rc
    printf '%s\n' $output | __scrollback_open
end
