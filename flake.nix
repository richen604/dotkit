{
  description = "Development environment with notcurses and zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
          ];

          shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.notcurses}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LIBRARY_PATH="${pkgs.libdeflate}/lib:$LIBRARY_PATH"
            echo "Development environment loaded with zig"
          '';
        };
      }
    );
}
