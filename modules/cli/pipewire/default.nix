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
    services.pipewire = {
      enable = true;

      extraConfig.pipewire."99-nix-visualizer-sink" = {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "nix-visualizer_sink";
              "node.description" = "nix-visualizer Sink";
              "media.class" = "Audio/Sink";
              "audio.position" = "FL,FR";
            };
          }
        ];
      };
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
