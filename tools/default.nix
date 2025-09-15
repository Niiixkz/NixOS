{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    jq
    gotop
    dust
    fastfetch
    libnotify
    inotify-tools
    ffmpeg
    libsixel
    p7zip
    brightnessctl
    socat
    wl-clipboard
    cliphist
  ];
}
