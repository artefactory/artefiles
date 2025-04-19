function watch-file --description "Watch file with syntax highlighting" --argument-names file language
    # Display help if no arguments or --help flag
    if test -z "$file" || test "$file" = "--help"
        echo "Usage: watch-file <filename> [language] [--bat-args \"bat arguments\"]"
        echo ""
        echo "Arguments:"
        echo "  <filename>         File to watch"
        echo "  [language]         Optional language for syntax highlighting (e.g., json, yaml, python)"
        echo "                     Only needed if bat can't auto-detect the language correctly"
        echo "  [--bat-args \"...\"] Optional arguments to pass directly to bat"
        echo ""
        echo "Examples:"
        echo "  watch-file server.log                     # Auto-detect syntax"
        echo "  watch-file data.txt json                  # Force JSON highlighting"
        echo "  watch-file log.txt --bat-args \"--plain\"   # Pass args to bat"
        echo ""
        echo "Common bat arguments:"
        echo "  --theme=<theme>    Set the color theme"
        echo "  --plain            Disable all decorations"
        echo "  --style=<style>    Comma-separated list of style components to display"
        return 1
    end

    # Parse for bat arguments
    set -l bat_args "--paging=never"
    set -l file_to_watch $file
    set -l lang $language

    # Check for --bat-args flag in arguments
    set -l args_index (contains -i -- "--bat-args" $argv)
    if test -n "$args_index" && test $args_index -gt 0 && test (count $argv) -gt $args_index
        # Get the bat arguments
        set bat_args "$bat_args $argv[(math $args_index + 1)]"
        # If language is actually bat args, clear it
        if test "$args_index" = 2
            set lang ""
        end
    end

    # Use tail to follow the file and pipe to bat for syntax highlighting
    if type -q bat
        if test -n "$lang"
            # Use specified language
            echo "Watching $file_to_watch with language: $lang"
            tail -f "$file_to_watch" | eval "bat $bat_args --language=$lang"
        else
            # Let bat auto-detect the syntax
            echo "Watching $file_to_watch with auto-detected language"
            tail -f "$file_to_watch" | eval "bat $bat_args"
        end
    else
        # Fallback to plain tail -f
        echo "Watching $file_to_watch (bat not installed, using plain tail)"
        tail -f "$file_to_watch"
    end
end
