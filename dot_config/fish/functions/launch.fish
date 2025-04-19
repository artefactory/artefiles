function launch --description "Run command in the background with nohup"
    if test (count $argv) -lt 1
        echo "Usage: launch <command> [arguments...] [logfile]"
        echo "Example: launch rsync -avz src/ dest/ log.txt"
        return 1
    end

    # Extract the command name (first argument)
    set -l cmd_name $argv[1]

    # Get all but the last argument (potential commands and args)
    set -l args_no_last $argv[1..-2]

    # Get the last argument (potential logfile)
    set -l last_arg $argv[-1]

    # Check if the last argument might be a logfile (ends with .log)
    if string match -q "*.log" $last_arg
        set logfile $last_arg
        set cmd_args $args_no_last
    else
        # Default log file
        set logfile "nohup.log"
        set cmd_args $argv
    end

    # Convert arguments array to string
    set -l cmd_str (string join " " $cmd_args)

    # Run the command with nohup
    echo "Starting command in background: $cmd_str"
    echo "Log file: $logfile"

    # Execute the command with nohup and redirect output to the log file
    nohup sh -c "$cmd_str" > "$logfile" 2>&1 &

    # Get the PID of the background process
    set -l pid $last_pid
    echo "Process started with PID: $pid"
    echo "To watch the log: watch-file $logfile"
end

# Add completion for the launch command
# Use the standard command completion for the first argument
complete -c launch -n "__fish_is_first_token" -a "(__fish_complete_command)"
