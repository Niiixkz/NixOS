{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "arcade-classic";
  version = "1.0.0";

  src = ./arcadeclassic.zip;

  unpackPhase = ''
    runHook preUnpack
    ${pkgs.unzip}/bin/unzip $src

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 ./ARCADECLASSIC.TTF -t $out/share/fonts/truetype

    runHook postInstall
  '';
}
