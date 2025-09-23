{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  programs.quickshell = {
    enable = true;
    package = inputs.quickshell.packages.${pkgs.system}.quickshell.withModules (
      with pkgs;
      [
        kdePackages.qtpositioning
        kdePackages.qt5compat
      ]
    );
  };

  home.packages = with pkgs; [
    python313Packages.opencv4
    python313Packages.numpy

    bc

    (writeShellScriptBin "python3-qs" ''
      nix-shell ${config.home.homeDirectory}/NixOS/shells/python3-quickshell.nix --run "python3 $@"
    '')
  ];
}
