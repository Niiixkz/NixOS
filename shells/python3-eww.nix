{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python313Packages.pygobject3
    python313Packages.dbus-python
    python313Packages.requests
    gdk-pixbuf
    gtk3
  ];
}
