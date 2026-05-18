_default:
    just --list

# Do prepush, and then push
push: prepush
    jj git push


# Serve dev build at <ip-addr>:8080
dev:
    hivemind

# Formats the files and builds, before pushing to remote
prepush: build format
    test -z "$(jj diff --name-only)" || jj new

# Format gleam and haskell code
format: _format-gleam _format-haskell

# Build gleam frontend
[working-directory: 'gleam-frontend']
build:
    gleam run -m lustre/dev build

[working-directory: 'gleam-frontend']
_format-gleam:
    gleam format

[working-directory: 'backend']
_format-haskell:
    fourmolu app --indentation 2 --mode inplace

