{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python313Packages.opencv4
    python313Packages.numpy
  ];
}
