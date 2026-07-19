{ pkgs, inputs, ... }:

let
  nixfmt-tree-withConfig = pkgs.nixfmt-tree.override {
    runtimeInputs = [ pkgs.nixfmt ];
    settings = {
      on-unmatched = "info";
      formatter.nixfmt = {
        command = "nixfmt";
        include = [ "*.nix" ];
      };
    };
  };
in
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
    nixfmt-tree-withConfig
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
