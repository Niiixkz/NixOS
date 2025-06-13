{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    cava
  ];

  home.file.".config/cava/my_config".source = ./config/my_config;
}
