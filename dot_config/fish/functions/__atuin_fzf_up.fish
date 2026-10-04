function __atuin_fzf_up --description 'up-arrow: atuin fzf picker on the first line, native up in a multi-line buffer'
    # Same guard as atuin's own up binding: inside the completion pager or a
    # history search the arrow keeps its native meaning.
    if commandline --search-mode; or commandline --paging-mode
        commandline -f up-or-search
        return
    end
    # In a multi-line command line the arrow must still move the cursor.
    if test (commandline -L) -gt 1
        commandline -f up-or-search
    else
        __atuin_fzf_search global
    end
end
