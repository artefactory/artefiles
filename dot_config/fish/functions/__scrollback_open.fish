function __scrollback_open --description 'Open stdin in $EDITOR at its last line, without escapes, then delete it'
    set -l dir /tmp
    set -q TMPDIR[1]; and set dir (string trim -r -c / -- $TMPDIR)
    # mktemp creates the file 0600: the output may hold secrets.
    set -l file (mktemp "$dir/scrollback.XXXXXX")
    or return 1
    __scrollback_strip >$file

    set -l editor vi
    set -q EDITOR[1]; and echo $EDITOR | read -at editor
    # A pipe into e leaves stdin at its end: the editor needs the terminal back.
    # The probe keeps a run without a terminal (a test, a script) working.
    if not test -t 0; and sh -c ': </dev/tty' 2>/dev/null
        $editor + $file </dev/tty
    else
        $editor + $file
    end
    set -l rc $status
    rm -f $file
    return $rc
end
