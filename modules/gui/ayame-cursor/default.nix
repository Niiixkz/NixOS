{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."${config.home.homeDirectory}/.icons/ayame-cursor".source =
        config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
