{
  description = "A small OS for x86 CPUs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShell {
          name = "lieu dev";
          packages = with pkgs; [
            zig_0_15
            grub2
            xorriso

            qemu
            bochs
          ];

          BXSHARE = "${pkgs.bochs}/share/bochs";
        };
      }
    );
}
