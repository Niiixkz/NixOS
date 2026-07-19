{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    system.stateVersion = "25.05";
  };

  homeModules =
    { config, ... }:
    {
    };
}
