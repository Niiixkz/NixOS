#!/bin/bash
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
CONFIG_DIR="$HOME/.config"

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
if [ $(pgrep -f random_wallpaper.sh | wc -l) -ge 3 ]; then
    exit 1
fi

better_discord_status=$(betterdiscordctl status)

if echo "$better_discord_status" | grep -q "BetterDiscord asar installed: (symbolic link) no" ||
    echo "$better_discord_status" | grep -q "Discord \"index.js\" injected: no"; then

    theme_dir="$CONFIG_DIR/BetterDiscord/themes"
    if [ ! -d "$theme_dir" ]; then
        mkdir -p "$theme_dir"
    fi

    error_output=$(betterdiscordctl reinstall 2>&1)

    if echo "$error_output" | grep -q "Not installed."; then
        betterdiscordctl install
    fi
fi

# wait for login
sleep 3

while true; do
    if check_any_stop_changing_wallpaper_process_exist; then
        sleep 300
        continue
    fi

    selected_wallpaper=$(
        find -L "${WALLPAPER_DIR}" -type f | shuf -n 1
    )

    swww img "$selected_wallpaper" --transition-type fade --transition-fps 60 --transition-duration 5

    sleep 2

    wal -i "$selected_wallpaper" -n

    swaync-client --reload-css

    cp ~/.cache/wal/foot.ini ~/.config/foot/foot.ini
    # cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf

    cp ~/.cache/wal/discord.theme.css ~/.config/BetterDiscord/themes/

    pywalfox update

    sleep 300
done
