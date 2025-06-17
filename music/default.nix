{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    mpc
  ];

  imports = [
    ./ncmpcpp/default.nix
    ./cava/default.nix
  ];
}
