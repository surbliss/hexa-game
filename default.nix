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
      hivemind

      nodejs
      superhtml
      typescript-language-server
      biome
      gleam
      inotify-tools # For lustre_dev auto-reload
      erlang # Also needed for lustre_dev
      rebar3
      # For lustre_dev_tools to render
      bun
      tailwindcss-language-server
      tailwindcss_4
    ];

    env = [
      # Set hive-mind env vars, to avoid adding cli arguments
      {
        name = "HIVEMIND_PROCESSES";
        value = "backend,gleam";
      }
      {
        name = "HIVEMIND_ROOT";
        eval = "$PRJ_ROOT";
      }
      {
        name = "HIVEMIND_ROOT";
        eval = "$PRJ_ROOT";
      }
    ];

    commands = [
      # Gleam
      {
        name = "w";
        help = "Backend + Gleam-frontend, with lustre_dev";
        command = "hivemind $PRJ_ROOT/Procfile";
      }
      # JS
      {
        name = "jw";
        help = "Backend with old JS-frontend";
        command = "hivemind $PRJ_ROOT/Procfile -l backend,javascript";
      }
      {
        name = "re";
        help = "Reload nix flake (personal command, using custom 'direnv reload' defined in nushell-config)";
        command = "direnv reload";
      }
      {
        name = "build";
        help = "Build Lustre frontend";
        command = "cd $PRJ_ROOT/gleam-frontend && gleam run -m lustre/dev build";
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
