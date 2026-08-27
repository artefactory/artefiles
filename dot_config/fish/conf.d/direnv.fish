# Shadows homebrew's vendor_conf.d/direnv.fish, which runs `direnv hook fish |
# source` eagerly on every startup (~30ms). Fish loads user conf.d before
# vendor conf.d and skips later files with the same basename, so this file
# wins. Same hook, but deferred to the first prompt and sourced from cache.
if type -q direnv
    function __init_direnv --on-event fish_prompt
        __cached_init direnv direnv hook fish
        functions --erase __init_direnv
    end
end
