{ pkgs, inputs, ... }:

{
  packages = with pkgs; [
    betterdiscordctl
    brightnessctl
    cliphist
    dust
    eyed3
    fastfetch
    fd
    ffmpeg
    file
    flac
    gcc
    gotop
    inotify-tools
    jq
    libnotify
    libsixel
    loudgain
    mpc
    p7zip
    rar
    socat
    unzip
    vim
    wl-clipboard
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
    };
}
