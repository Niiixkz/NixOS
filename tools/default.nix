{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gotop
    dust
  ];
}
