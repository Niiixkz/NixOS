if status is-interactive
    # Commands to run in interactive sessions can go here
    clear && fastfetch
    starship init fish | source
end

set -U fish_greeting

alias n="nvim"
