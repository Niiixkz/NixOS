{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
    pkgs.fish
  ];

  nixosModules = {
    programs.fish.enable = true;
  };

  homeModules =
    { config, ... }:
    {
      programs.fish = {
        enable = true;

        shellAliases = {
          h = "hx";
        };

        interactiveShellInit = ''
          set -g fish_greeting

          clear
          fastfetch
        '';

        functions = {
          t = ''
            cd ~/NixOS
            or begin
                echo "Failed to change directory"
                return 1
            end

            git add .

            git diff --cached --quiet
            and begin
                echo "Nothing to commit."
            end
            or begin
                git commit -m a
                or return 1
            end

            nh os test
          '';
        };
      };
    };
}
