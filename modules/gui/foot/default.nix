{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.foot
  ];

  nixosModules = {
  };

  homeModules =
    { config, lib, ... }:
    {
      home.activation.createFolder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.config/foot"
      '';
    };
}
