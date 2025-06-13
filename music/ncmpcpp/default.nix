{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    ncmpcpp
  ];

  home.file.".config/ncmpcpp" = {
    source = ./config;
    recursive = true;
  };
}
