{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./cli
    ./gui
  ];
}
