{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    time.timeZone = "Asia/Taipei";
  };

  homeModules =
    { config, ... }:
    {
    };
}
