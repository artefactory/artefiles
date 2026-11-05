function e --description 'Open stdin in $EDITOR without escapes (cmd | e); with a terminal on stdin, run $EDITOR'
    if test -t 0
        set -l editor vi
        set -q EDITOR[1]; and echo $EDITOR | read -at editor
        $editor $argv
    else
        __scrollback_open
    end
end
