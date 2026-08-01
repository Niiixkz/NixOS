{
  networking = {
    hostName = "NixOS";
    networkmanager.enable = true;
    proxy.noProxy = "127.0.0.1,localhost,internal.domain";
    enableIPv6 = false;
  };
}
