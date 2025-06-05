{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    pywal
  ];

  home.file.".config/wal" = {
    source = ./config;
    recursive = true;
  };
}
