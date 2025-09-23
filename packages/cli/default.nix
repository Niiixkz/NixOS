{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    betterdiscordctl
    brightnessctl
    clementine
    cliphist
    dust
    eyed3
    fastfetch
    fd
    ffmpeg
    flac
    gotop
    inotify-tools
    jq
    libnotify
    libsixel
    loudgain
    mpc
    p7zip
    socat
    swww
    wl-clipboard
  ];

  imports = [
    ./cava
    ./fcitx5
    ./fish
    ./git
    ./ncmpcpp
    ./nvim
    ./pywal
    ./starship
  ];
}
