if type -q zoxide
    function __zoxide_cd_complete
        set -l token (commandline -ct)
        if test -z "$token"
            zoxide query -l
        else
            zoxide query -l -- $token
        end
    end
    complete -c cd -k -a '(__zoxide_cd_complete)' -d 'zoxide'
end
