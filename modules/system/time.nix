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
    time.timeZone = "Asia/Taipei";
  };

  homeModules =
    { config, ... }:
    {
    };
}
