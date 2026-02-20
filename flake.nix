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
          default = (self.apple-libs.${system} pkgs.apple-sdk).haskell-obj-c;
        };

        apple-libs = sdk: 
          let
            frameworks = sdk.outPath + "/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks";
            entries = builtins.readDir frameworks;
            stripExt = name: builtins.replaceStrings [ ".framework" ] [ "" ] name;
          in {
              haskell-obj-c = pkgs.haskellPackages.callCabal2nix "haskell-obj-c" ./. {
                objc = sdk;
              };
            } // 
          (pkgs.lib.attrsets.concatMapAttrs (name: _: 
            let frameworkName = pkgs.lib.strings.toLower (stripExt name);
            in { "apple-${frameworkName}-gen" = pkgs.haskellPackages.callPackage ./generate.nix {}; }
          ) entries);

      });
}
