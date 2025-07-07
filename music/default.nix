{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    mpc
    loudgain
    eyed3
    flac
    clementine
  ];

  imports = [
    ./ncmpcpp/default.nix
    ./cava/default.nix
  ];
}
