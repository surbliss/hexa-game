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
      vscode-langservers-extracted
      superhtml
      typescript-language-server
    ];

    commands = [
      {
        name = "s";
        help = "serve";
        command = "npx live-server static";
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
