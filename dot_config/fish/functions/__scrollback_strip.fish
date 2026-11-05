function __scrollback_strip --description "Drop ANSI escapes and carriage-return redraws from stdin"
    # string reads only a stdin redirected to it directly, never a function's:
    # cat hands it the function's stdin. OSC goes first: its body (a title, a
    # hyperlink) would otherwise survive as text.
    command cat | string replace -ra '\e\][^\a\e]*(?:\a|\e\\\\)' '' |
        string replace -ra '\e\[[0-?]*[ -/]*[@-~]' '' |
        string replace -ra '\e[()*+#%].' '' |
        string replace -ra '\e.?' '' |
        string replace -ra '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]' '' |
        # A trailing CR is a line ending, not a redraw: drop it before keeping
        # only the text after a line's last CR.
        string replace -r '\r+$' '' |
        string replace -r '^[\s\S]*\r' ''
    # string replace exits 1 when no line matched, which here is clean input.
    return 0
end
