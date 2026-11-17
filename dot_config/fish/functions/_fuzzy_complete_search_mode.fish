function _fuzzy_complete_search_mode --description 'Choose whether fzf filters the picker for a query'
    # Usage: _fuzzy_complete_search_mode <query>
    # Prints `disable-search` when fzf cannot match <query> against the
    # candidates as typed, else `enable-search`:
    # - a '*' wildcard, since fzf reads it literally (the reload globs it);
    # - a backslash escape other than '\ ' (e.g. `\(` after Tab inserted
    #   `p\ \(1\)/`), since fzf unescapes only '\ '.
    # With search off, the reload's own candidates are the filter.
    # Runs on every keystroke, so it calls no other function. Pure.
    if string match -qr -- '\*|\\\\[^ ]' $argv[1]
        echo disable-search
    else
        echo enable-search
    end
end
