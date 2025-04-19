function is_vscode_terminal
    test -n "$VSCODE_INJECTION" -o -n "$VSCODE_PID"
end

function smart_bat
    if is_vscode_terminal
        if test -t 1  # If output is going to a terminal
            command bat --style=numbers,changes --pager="less -FRX" $argv
        else
            command bat --style=plain --color=always --pager=never $argv
        end
    else
        command bat --style=auto $argv
    end
end
