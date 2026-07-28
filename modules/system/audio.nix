{
  pkgs,
  inputs,
  diskDir,
  ...
}:

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
