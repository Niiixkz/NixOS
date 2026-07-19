{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    programs.fish.enable = true;
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."fish".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
