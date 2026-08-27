# Source a tool's generated shell init from a cache file, regenerating it only
# when the tool's binary is newer than the cache. Tools like atuin, direnv and
# fzf emit identical fish code on every shell start; caching it trades a
# process spawn per startup for a stat.
#
#   __cached_init atuin atuin init fish --disable-up-arrow
#
# argv[1] names the cache file; argv[2..] is the command emitting fish code.
# If generation fails the cache is left untouched and the command is sourced
# directly, so a broken cache can never silently disable the tool.
function __cached_init --argument-names key
    set -l generator $argv[2..]
    test (count $generator) -gt 0; or return 1

    set -l bin (command -v $generator[1])
    test -n "$bin"; or return 1

    set -l cache $__fish_cache_dir/init-$key.fish

    if not test -f $cache; or test $bin -nt $cache
        command mkdir -p $__fish_cache_dir
        set -l tmp $cache.tmp.$fish_pid
        if $generator >$tmp 2>/dev/null; and test -s $tmp
            command mv -f $tmp $cache
        else
            command rm -f $tmp
            $generator | source
            return
        end
    end

    source $cache
end
