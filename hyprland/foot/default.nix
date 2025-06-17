{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    foot
  ];

  home.activation.createFolder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/foot"
  '';

  imports = [
    ./starship/default.nix
  ];
}
