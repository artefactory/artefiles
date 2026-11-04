function vscode_remote_check --description "Check that VS Code (Remote-SSH, Dev Containers) can read this machine's login shell environment"
    # VS Code reads the environment by running `$SHELL -ilc` with
    # VSCODE_RESOLVING_ENVIRONMENT=1 and gives up after 10 seconds. This runs the
    # same probe. Its stdin is a pipe that stays open with nothing to read, so a
    # startup file that reads input hangs here as it does under VS Code, instead
    # of reading end-of-file and passing.
    #
    # --probe prints only the probe result, for dotfiles_doctor.
    # Returns 1 when the probe times out or does not print its marker.
    argparse probe -- $argv; or return 2

    set -l limit 10
    if set -q VSCODE_REMOTE_CHECK_TIMEOUT
        set limit $VSCODE_REMOTE_CHECK_TIMEOUT
    end

    # VS Code uses $SHELL, which sshd sets to the login shell.
    set -l login_shell $SHELL
    if test -z "$login_shell"
        set login_shell (getent passwd (id -un) 2>/dev/null | cut -d: -f7)
    end
    if test -z "$login_shell"
        echo "vscode_remote_check: cannot tell the login shell (SHELL is not set)" >&2
        return 1
    end

    set -l dir (mktemp -d); or return 1
    # POSIX sh, because fish background jobs cannot be waited on with a timeout.
    sh -c '
        shell=$1 limit=$2 dir=$3
        mkfifo "$dir/in" || exit 2
        sleep $((limit + 5)) > "$dir/in" &
        writer=$!
        start=$(date +%s)
        VSCODE_RESOLVING_ENVIRONMENT=1 "$shell" -ilc "echo __ok__" < "$dir/in" > "$dir/out" 2>&1 &
        probe=$!
        ( sleep "$limit" && { : > "$dir/timeout"; pkill -P "$probe"; kill "$probe"; } ) > /dev/null 2>&1 &
        watcher=$!
        wait "$probe"
        end=$(date +%s)
        pkill -P "$watcher" 2> /dev/null
        kill "$watcher" "$writer" 2> /dev/null
        echo $((end - start)) > "$dir/secs"
        [ -f "$dir/timeout" ] && exit 124
        grep -q __ok__ "$dir/out" || exit 1
        exit 0
    ' sh $login_shell $limit $dir 2>/dev/null
    # stderr is dropped: sh reports the jobs it kills. The probe's own output
    # is in $dir/out.
    set -l probe_status $status
    set -l secs (cat $dir/secs 2>/dev/null)
    set -l out (head -n 3 $dir/out 2>/dev/null)
    rm -rf $dir

    set -l result
    switch $probe_status
        case 0
            set result "answered in $secs s (limit $limit s)"
        case 124
            set result "no answer within $limit s: a startup file is slow or waits for input"
        case 1
            set result "exited after $secs s without printing its marker: "(string join ' | ' -- $out)
        case '*'
            set result "could not run the probe"
    end

    if set -q _flag_probe
        echo $result
        test $probe_status -eq 0
        return
    end

    echo "login shell: $login_shell"
    if test $probe_status -eq 0
        echo "  ✓ VS Code environment probe: $result"
    else
        echo "  ✗ VS Code environment probe: $result"
        echo "    Probe by hand: env VSCODE_RESOLVING_ENVIRONMENT=1 $login_shell -ilc 'echo __ok__'"
    end
    if not set -q TERM
        echo "  ! TERM is not set: old fish versions crash without it; ssh -t or a terminal sets it"
    end
    echo ""
    echo "If Remote-SSH still fails to connect, run vscode_remote_fix on the machine that runs VS Code:"
    echo '    it sets "remote.SSH.useLocalServer": false in its user settings.json'
    echo 'Dev Containers: "userEnvProbe": "loginInteractiveShell" works once this probe passes.'
    test $probe_status -eq 0
end
