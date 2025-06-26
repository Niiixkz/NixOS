#!/bin/bash

current=$(asusctl profile -p | grep -oE 'Quiet|Balanced|Performance')

profiles=("Quiet" "Balanced" "Performance")

for i in "${!profiles[@]}"; do
    if [[ "${profiles[$i]}" == "$current" ]]; then
        next_index=$(((i + 1) % ${#profiles[@]}))
        next_profile=${profiles[$next_index]}
        break
    fi
done

asusctl profile -P "$next_profile"

notify-send "ASUS Profile Switched" "Now using: $next_profile"
