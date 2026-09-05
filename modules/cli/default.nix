{
  pkgs,
  inputs,
  diskDir,
  ...
}:

let
  llama-cpp = pkgs.llama-cpp.override { cudaSupport = true; };
  presenterm = inputs.presenterm.packages.${pkgs.stdenv.hostPlatform.system}.default;
  nix-visualizer = inputs.nix-visualizer.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
    kdePackages.qttools
    libnotify
    libsixel
    llama-cpp
    loudgain
    mpc
    nix-visualizer
    p7zip
    presenterm
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
