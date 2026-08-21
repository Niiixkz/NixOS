{
  config,
  ...
}:

{
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      extra-substituters = [
        "https://cache.nixos-cuda.org/"
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
}
