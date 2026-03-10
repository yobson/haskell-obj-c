{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    haskell-obj-c.url = "path:../.";
    haskell-obj-c.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, haskell-obj-c }: 
    flake-utils.lib.eachSystem [
      flake-utils.lib.system.aarch64-darwin 
      flake-utils.lib.system.x86_64-darwin
    ] 
    (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        sdk = pkgs.apple-sdk;
        apple-libs = haskell-obj-c.apple-libs.${system} sdk;
      in {
        packages = {
          default = pkgs.haskellPackages.callCabal2nix "todo-list" ./. {
            haskell-obj-c = apple-libs.haskell-obj-c;
            apple-appkit-gen = apple-libs.apple-appkit-gen;
            apple-foundation-gen = apple-libs.apple-foundation-gen;
          }; 
        };

        devShells.default = pkgs.haskellPackages.shellFor {
          packages = p: [ self.packages.${system}.default ];
          nativeBuildInputs = with pkgs; [ cabal-install haskell-language-server ];
        };
      });
      }
