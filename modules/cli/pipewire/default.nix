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

      extraConfig.pipewire."99-cava-sink" = {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "cava_sink";
              "node.description" = "Cava Sink";
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
