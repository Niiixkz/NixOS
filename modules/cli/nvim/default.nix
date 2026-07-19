{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.neovim
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
