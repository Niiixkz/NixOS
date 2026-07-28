{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
  ];

  nixosModules =
    { config, ... }:
    {
      nix = {
        settings = {
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
        };

        gc = {
          automatic = true;
          dates = "daily";
        };
      };

      systemd.services.nix-gc.wants = [ "nix-gen-gc.service" ];

      systemd.services.nix-gen-gc = {
        description = "NixOS Generation Garbage Collector";
        script = "exec ${config.nix.package.out}/bin/nix-env -vvvv --profile /nix/var/nix/profiles/system --delete-generations +5";
        serviceConfig.Type = "oneshot";
      };
    };

  homeModules =
    { config, ... }:
    {
    };
}
