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

    folders=("$WALLPAPER_DIR"/*/)
    total=${#folders[@]}

    random_index=$((RANDOM % total))
    selected="${folders[$random_index]}"

    hor_image=$(find "$selected" -maxdepth 1 -type f -name "H.*")
    vec_image=$(find "$selected" -maxdepth 1 -type f -name "V.*")

    swww img "$hor_image" --outputs eDP-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200
    swww img "$hor_image" --outputs HDMI-A-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200
    swww img "$vec_image" --outputs DP-1 --transition-type fade --transition-fps 30 --transition-duration 5 --transition-step 200

    sleep 2

    wal -i "$hor_image" -n

    swaync-client --reload-css

    cp ~/.cache/wal/foot.ini ~/.config/foot/foot.ini
    # cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf

    cp ~/.cache/wal/discord.theme.css ~/.config/BetterDiscord/themes/

    pywalfox update

    sleep 300
done
