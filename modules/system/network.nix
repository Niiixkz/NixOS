{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    networking.hostName = "NixOS";
    networking.networkmanager.enable = true;
    networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  homeModules =
    { config, ... }:
    {
    };
}
