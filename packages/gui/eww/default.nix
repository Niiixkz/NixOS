{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  programs.eww = {
    enable = true;
    package = inputs.eww.packages.${pkgs.system}.eww;
  };

  home.packages = with pkgs; [
    python313Packages.pygobject3
    python313Packages.dbus-python
    python313Packages.requests
    gdk-pixbuf
    gtk3

    (writeShellScriptBin "python3-eww" ''
      nix-shell ${config.home.homeDirectory}/NixOS/shells/python3-eww.nix --run "python3 $@"
    '')
  ];
}
