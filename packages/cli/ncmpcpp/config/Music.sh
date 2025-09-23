#!/bin/bash

declare -A windows=(
    [playlist]="foot --title playlist ncmpcpp --config=\"$HOME/.config/ncmpcpp/Playlist.conf\" --bindings=\"$HOME/.config/ncmpcpp/PlaylistBindings\" &"
    [playback_panel]="foot --title playback_panel ncmpcpp --config=\"$HOME/.config/ncmpcpp/PlaybackPanel.conf\" --bindings=\"$HOME/.config/ncmpcpp/PlaybackPanelBindings\" &"
    [album_cover]="foot --title album_cover bash \"$HOME/.config/ncmpcpp/AlbumCover.sh\" &"
    [cava]="foot --title cava -o font=\"DejaVu Sans Mono:size=8\" cava -p $HOME/.config/cava/my_config &"
)

current_ws=$(hyprctl monitors -j | jq -r '.[] | select(.name == "eDP-1") | .activeWorkspace.id')
music_ws=100

all_running=true
for title in "${!windows[@]}"; do
    if ! pgrep -f "foot.*--title $title" >/dev/null; then
        all_running=false
        break
    fi
done

if [[ "$current_ws" == "$music_ws" && "$all_running" == true ]]; then
    for title in "${!windows[@]}"; do
        pkill -f "foot.*--title $title"
    done

    hyprctl dispatch workspace $(cat "/tmp/NcmpcppPreviousWorkspace")
else
    mpc repeat on
    mpc crossfade 5
    hyprctl dispatch workspace "$music_ws"
    for title in "${!windows[@]}"; do
        if ! pgrep -f "foot.*--title $title" >/dev/null; then
            eval "${windows[$title]}"
            sleep 0.1
        fi
    done

    echo "$current_ws" >"/tmp/NcmpcppPreviousWorkspace"
fi
