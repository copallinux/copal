# command:  ollama
# purpose:  Run large language models locally: download a model, then chat with it or call it from programs.
# why:      The store's local AI, on the 64-bit boards: small models run on a
#           Pi 5's CPU, offline, with nothing sent anywhere.
# see:      python3, curl

## Use
Start the server, then pull a model and run it. The server stays running
and answers programs on port 11434; `ollama run` gives a chat prompt.

## Examples
    ollama serve &                       # start the server (no service is installed)
    ollama pull llama3.2:1b              # a small model, about 1.3 GB
    ollama run llama3.2:1b               # chat; /bye to leave
    ollama list                          # the models downloaded
    ollama ps                            # which are loaded, and in what memory
    ollama rm llama3.2:1b                # free the space

## Options
serve           start the server
pull MODEL      download a model
run MODEL       chat with it (pulls it first if needed)
list            the downloaded models
ps              the running ones
stop MODEL      unload one
rm MODEL        delete one

## Notes
- Models are large: each is gigabytes, kept in `~/.ollama/models`. On
  a small card, one small model is the budget.
- Speed depends on memory: a model bigger than free RAM swaps and
  crawls. On a 4 GB Pi, 1B to 3B models are the practical size.
- 64-bit boards only: its row is gated to aarch64 and x86_64.
