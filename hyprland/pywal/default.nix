{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    pywal
    imagemagick
  ];

  home.file.".config/wal" = {
    source = ./config;
    recursive = true;
  };
}
