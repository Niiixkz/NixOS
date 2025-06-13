#!/bin/bash

declare -A windows=(
    [playlist]="foot --title playlist ncmpcpp --config=\"$HOME/.config/ncmpcpp/Playlist.conf\" --bindings=\"$HOME/.config/ncmpcpp/PlaylistBindings\" &"
    [playback_panel]="foot --title playback_panel ncmpcpp --config=\"$HOME/.config/ncmpcpp/PlaybackPanel.conf\" --bindings=\"$HOME/.config/ncmpcpp/PlaybackPanelBindings\" &"
    [album_cover]="foot --title album_cover bash \"$HOME/.config/ncmpcpp/AlbumCover.sh\" &"
    [cava]="foot --title cava -o font=\"DejaVu Sans Mono:size=8\" cava -p $HOME/.config/cava/my_config &"
)

current_ws=$(hyprctl activeworkspace -j | jq '.id')
music_ws=11

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

    hyprctl dispatch workspace $(cat "$HOME/.config/ncmpcpp/PreviousWorkspace")
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

    echo "$current_ws" >"$HOME/.config/ncmpcpp/PreviousWorkspace"
fi
