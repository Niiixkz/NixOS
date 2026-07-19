{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    services.pipewire = {
      enable = true;
      pulse.enable = true;
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
