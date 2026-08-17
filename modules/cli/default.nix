{
  pkgs,
  inputs,
  diskDir,
  ...
}:

let
  llama-cpp = pkgs.llama-cpp.override { cudaSupport = true; };
in
{
  packages = with pkgs; [
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
    llama-cpp
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
