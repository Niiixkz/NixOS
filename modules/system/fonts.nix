{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.dejavu-sans-mono
      material-symbols
    ];
  };

  homeModules =
    { config, ... }:
    {
    };
}
