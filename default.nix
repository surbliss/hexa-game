{ pkgs, config, ... }:
{
  haskellProjects.haskell = {
    # Default settings. For other settings, see
    # https://flake.parts/options/haskell-flake.html
    devShell.tools = hp: { inherit (hp) cabal-gild; };
    projectRoot = ./backend;
  };

  devshells.other = {
    packages = with pkgs; [
      # For handling running background-processes
      overmind

      nodejs
      superhtml
      typescript-language-server
      biome
      gleam
      inotify-tools # For lustre_dev auto-reload
      erlang # Also needed for lustre_dev
      rebar3
    ];

    commands = [
      # Gleam
      {
        name = "gw";
        help = "Backend + Gleam-frontend, with lustre_dev";
        command = "overmind start -l backend,gleam";
      }
      # JS
      {
        name = "jw";
        help = "Backend + JS-frontend";
        command = "overmind start -l backend,javascript";
      }
      # Quit overmind process
      {
        name = "q";
        help = "quit overmind process";
        command = "overmind q";
      }
      {
        name = "re";
        help = "Reload nix flake (personal command, using custom 'direnv reload' defined in nushell-config)";
        command = "direnv reload";
      }
    ];
  };

  devShells.default = pkgs.mkShell {
    inputsFrom = [
      config.haskellProjects.haskell.outputs.devShell
      config.devShells.other
    ];
  };
}
