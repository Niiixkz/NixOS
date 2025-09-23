#!/bin/bash

cd "$HOME/.config/eww"

CONFIG_DIR="$HOME/.config"
MONITOR_DIR="/tmp/eww_wallpaper_trigger"

[ -d "$MONITOR_DIR" ] || mkdir -p "$MONITOR_DIR"
rm -f "$MONITOR_DIR"/*

stop_changing_wallpaper_process_list=("osu!" "hyprlock" "neovim")

check_any_stop_changing_wallpaper_process_exist() {
    for process in "${stop_changing_wallpaper_process_list[@]}"; do
        if pgrep -f "$process" >/dev/null; then
            return 0
        fi
    done
    return 1
}

# original, current and $() will open a subprocess or something so count increase 1
if [ $(pgrep -f wallpaper_backend.sh | wc -l) -ge 3 ]; then
    exit 1
fi

update_wallpaper_and_config() {
    number=$(jq ".list[$index].number" <<<"$wallpaper_data")
    ext=$(jq -r ".list[$index].ext" <<<"$wallpaper_data")

    swww img "$HOME/.config/hypr/wallpapers/${number}/H.${ext}" --outputs eDP-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200 &
    swww img "$HOME/.config/hypr/wallpapers/${number}/H.${ext}" --outputs HDMI-A-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200 &
    swww img "$HOME/.config/hypr/wallpapers/${number}/V.${ext}" --outputs DP-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200 &

    sleep 2

    wal -i "$HOME/.config/hypr/wallpapers/${number}/H.${ext}" -n

    eww reload --onlycss
    eww update wallpaper_data="$wallpaper_data" wallpaper_current_index="$index"

    # swaync-client --reload-css &

    cp ~/.cache/wal/foot.ini ~/.config/foot/foot.ini &
    # cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf

    cp ~/.cache/wal/discord.theme.css ~/.config/BetterDiscord/themes/ &

    pywalfox update
}

bash "$HOME/.config/BetterDiscord/init.sh"

# wait for login
sleep 3

wallpaper_data=$(
    printf '%s\n' $HOME/.config/hypr/wallpapers/*/H.{jpg,png} 2>/dev/null |
        grep -v '\*' |
        sed -E 's|.*/([0-9]+)/H\.(.*)|\1:\2|' |
        shuf |
        jq -Rnc '[inputs | split(":") | {number:(.[0]|tonumber), ext:.[1]}] as $list | {total:($list|length), list:$list}'
)

total=$(jq '.total' <<<"$wallpaper_data")

index=0
previous_index=0

update_wallpaper_and_config

while true; do
    if file=$(inotifywait -t 300 -e close_write --format '%f' "$MONITOR_DIR"); then
        read -r index <"${MONITOR_DIR}/${file}"
    else
        index=$((($index + 1) % total))
    fi

    if check_any_stop_changing_wallpaper_process_exist; then
        index=$previous_index
        continue
    fi

    update_wallpaper_and_config

    previous_index=$index

    rm -f "$MONITOR_DIR"/*
done
