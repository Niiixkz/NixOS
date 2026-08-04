if status is-interactive
    # Commands to run in interactive sessions can go here
    clear && fastfetch
    starship init fish | source
end

set -U fish_greeting

alias h="hx"

function t
    cd /home/niiixkz/NixOS
    or begin
        echo "Failed to change directory"
        return 1
    end

    git add .

    git diff --cached --quiet
    and begin
        echo "Nothing to commit."
    end
    or begin
        git commit -m a
        or return 1
    end

    sudo nixos-rebuild test
end
