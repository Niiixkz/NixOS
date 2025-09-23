#!/bin/bash

declare -A rewrite_icon=(
    ["default"]=" "
    ["title<osu!.*>"]="󰺷 "
    ["title<LINE>"]=" "
    ["class<firefox>"]=" "
    ["class<kitty>"]=" "
    ["class<foot>"]=" "
    ["class<discord>"]=" "
    ["class<mpv>"]=" "
    ["class<org.clementine_player.Clementine>"]="󰎆 "
    ["title<.*Picture-in-Picture.*>"]=" "
    ["class<vlc>"]="󰕼 "
    ["title<.*jira.*>"]=" "
    ["class<obs>"]=" "
    ["class<com.obsproject.Studio>"]=" "
    ["class<steam>"]=" "
    ["class<emulator>"]="󰄜 "
)

get_icon() {
    local class="$1"
    local title="$2"

    for pattern in "${!rewrite_icon[@]}"; do
        if [[ "$pattern" == class\<* ]]; then
            regex="${pattern#class<}"
            regex="${regex%>}"
            [[ "$class" =~ $regex ]] && echo -n "${rewrite_icon[$pattern]}" && return
        elif [[ "$pattern" == title\<* ]]; then
            regex="${pattern#title<}"
            regex="${regex%>}"
            [[ "$title" =~ $regex ]] && echo -n "${rewrite_icon[$pattern]}" && return
        fi
    done

    echo -n "${rewrite_icon[default]}"
}

update_workspace() {
    local workspace_icon=()
    local workspace_class=()
    local output=""

    workspace_data=$(hyprctl workspaces -j)
    window_data=$(hyprctl clients -j)
    active_workspaces=$(hyprctl monitors -j | jq -r '.[] | .activeWorkspace.id' | xargs)

    for ((i = 1; i <= 8; i++)); do
        windows=$(echo "$workspace_data" | jq -r "[.[] | select(.id == ${i})] | .[0]?.windows // 0")

        icons="$i"

        if [[ "$windows" -gt 0 ]]; then
            clients=$(echo "$window_data" | jq -r ".[] | select(.workspace.id == $i) | {class: .class, title: .title} | @base64")
            while read -r encoded; do
                [[ -z "$encoded" ]] && continue
                decoded=$(echo "$encoded" | base64 --decode)
                class=$(echo "$decoded" | jq -r '.class' | tr -d '\0')
                title=$(echo "$decoded" | jq -r '.title' | tr -d '\0')
                icon=$(get_icon "$class" "$title")
                icons+=" $icon"
            done <<<"$clients"
        fi

        workspace_icon+=("$icons")

        if [[ " $active_workspaces " == *" $i "* ]]; then
            workspace_class+=("visiting")
        elif [[ "$windows" -gt 0 ]]; then
            workspace_class+=("occupied")
        else
            workspace_class+=("free")
        fi
    done

    output="(box :class \"ws\" :halign \"end\" :orientation \"h\" :spacing 5 :space-evenly \"false\""
    for i in {1..8}; do
        idx=$((i - 1))
        output+=" (eventbox :onclick \"hyprctl dispatch workspace $i\" :cursor \"pointer\" :class \"${workspace_class[$idx]}\" (box :class \"ws-box\" (label :text \"${workspace_icon[$idx]}\")))"
    done
    output+=")"
    eww update workspace_output="$output"
}

HYPRLAND_SIGNATURE_ACTUAL=$(ls -td /run/user/1000/hypr/*/ | head -n1 | xargs basename)
SOCKET="/run/user/1000/hypr/${HYPRLAND_SIGNATURE_ACTUAL}/.socket2.sock"

stdbuf -oL socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
    case $line in
    "workspace>>"* | "createworkspace>>"* | "destroyworkspace>>"* | "openwindow>>"* | "closewindow>>"* | "movewindow>>"*)
        update_workspace
        ;;
    esac
done
