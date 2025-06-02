{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];

  home.file.".config/swaync/" = {
    source = ./config;
    recursive = true;
  };
}
