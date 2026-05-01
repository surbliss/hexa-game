{
  description = "Hexa-game development flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
    devshell.url = "github:numtide/devshell";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.haskell-flake.flakeModule
        inputs.devshell.flakeModule
      ];
      systems = [ "x86_64-linux" ];
      perSystem = import ./.;
    };
}
