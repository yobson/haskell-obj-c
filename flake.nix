{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachSystem [
      flake-utils.lib.system.aarch64-darwin 
      flake-utils.lib.system.x86_64-darwin
    ] 
    (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages = {
          bundler = pkgs.haskellPackages.callCabal2nix "haskell-obj-c-bundler" ./bundler {};
          codegen = pkgs.haskellPackages.callCabal2nix "haskell-obj-c-codegen" ./codegen {};
          default = (self.apple-libs.${system} pkgs.apple-sdk).apple-foundation-gen;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.apple-sdk_26 ];
          packages = [ self.packages.${system}.codegen ];
        };

        apple-libs = sdk:
          let
            frameworks = sdk.outPath + "/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks";
            src = pkgs.stdenv.mkDerivation {
              name = "apple-haskell-binding-src";
              nativeBuildInputs = [
                self.packages.${system}.codegen
                sdk
              ];

              phases = ["installPhase"];
              installPhase = ''
                args=(-o "$out")
                for fw in "${frameworks}"/*.framework; do
                  name=$(basename "$fw" .framework)
                  args+=(-f "$name")
                done

                mkdir -p $out
                objc-codegen "''${args[@]}"
                ls $out
              '';
            };

            sourceEntries = builtins.readDir src;
            libNames = builtins.attrNames 
              (pkgs.lib.filterAttrs (name: type: type == "directory") sourceEntries);

            
            hpkgs =
              pkgs.haskellPackages.override {
                overrides = self: super: {
                  haskell-obj-c =
                    self.callCabal2nix "haskell-obj-c" ./. { objc = sdk; };

                } // pkgs.lib.genAttrs libNames (name:
                self.callCabal2nix name "${src}/${name}" {}
              );
            };
            generatedPkgs = {
              haskell-obj-c = hpkgs.haskell-obj-c;
              libs = pkgs.lib.genAttrs libNames (name: hpkgs.${name});
            };

          in generatedPkgs.libs // { haskell-obj-c = generatedPkgs.haskell-obj-c; };
      });
}
