# command:  elixir
# purpose:  Elixir: a friendly functional language on the Erlang VM, built for concurrency.
# why:      The catalogue's Elixir, with iex for trying things and mix for
#           projects: millions of lightweight processes, on a Pi.
# see:      ruby, erlang

## Use
`iex` is the interactive shell. `elixir` runs a script (`.exs`). `mix`
creates, builds, tests and runs projects.

## Examples
    iex                                  # the interactive shell; Ctrl-C twice to leave
    elixir script.exs                    # run a script
    elixir -e 'IO.puts 6 * 7'            # one expression
    mix new hello && cd hello            # a new project
    mix test                             # its tests;  mix run to run it

## Options
-e CODE        evaluate CODE
-r FILE        require FILE first
--no-halt      keep the VM running after the script
-v, --version  the Elixir and Erlang versions

## Notes
- `mix deps.get` fetches dependencies from hex.pm; the first time it
  asks to install Hex itself -- answer yes.
- It is Erlang underneath: `erl` is also here, and Erlang libraries
  work from Elixir.
