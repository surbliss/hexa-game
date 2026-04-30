{ pkgs, config, ... }:
{
  haskellProjects.haskell = {
    # Default settings. For other settings, see
    # https://flake.parts/options/haskell-flake.html
    devShell.tools = hp: { inherit (hp) cabal-gild; };
    devShell.mkShellArgs = {
      packages = [ pkgs.python3 ];
    };
  };

  devshells.other = {
    packages = with pkgs; [
      nodejs
      python3
      superhtml
      typescript-language-server
      biome

    ];

    commands = [
      {
        name = "s";
        help = "serve (at 192.168.0.60:8080)";
        command = "npx live-server --no-browser static";
      }
      {
        name = "r";
        help = "cabal run";
        command = "cabal run";
      }
      {
        name = "w";
        help = "server + watch cabal run";
        command = "npx live-server --no-browser static & watchexec -e hs --restart cabal run";
      }
      {
        name = "re";
        help = "direnv reload (after default.nix changes)";
        command = "direnv reload";
      }
    ];
  };

  devShells.default = pkgs.mkShell {
    inputsFrom = [
      config.haskellProjects.haskell.outputs.devShell
      config.devShells.other
    ];
    # packages = with pkgs; [
    #   nodejs
    #   python3
    #   vscode-langservers-extracted
    #   superhtml
    #   typescript-language-server
    # ];
  };
}
