{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    services.power-profiles-daemon.enable = true;
  };

  homeModules =
    { config, ... }:
    {
    };
}
