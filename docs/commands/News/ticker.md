# command:  ticker
# purpose:  Live stock and crypto prices in the terminal, with your holdings' gains and losses.
# why:      The catalogue's market watch: a small full-screen table of prices
#           that updates itself, for a spare terminal or a tmux pane.
# see:      tmux

## Use
Give it the symbols to watch, or keep them -- and what you hold -- in a
config file. It refreshes on its own; q quits.

## Examples
    ticker -w AAPL,MSFT,BTC-USD          # watch these
    ticker -w AAPL -i 10                 # refresh every 10 seconds
    ticker --show-summary --show-holdings   # with the config's positions
    ticker print                         # holdings once, as text, and exit

## Options
-w, --watchlist LIST     symbols to watch, comma-separated
-i, --interval SECONDS   refresh period
--config FILE            the config (default ~/.ticker.yaml)
--show-summary           total gain and loss for your positions
--show-holdings          cost, quantity and weight per position
--show-fundamentals      open, high, low and volume
--sort alpha|value       the order of the list

## Notes
- Symbols are Yahoo Finance's: `BTC-USD` for Bitcoin, `^GSPC` for the
  S&P 500, a suffix for other exchanges (`VOD.L` in London).
- Quotes are delayed by the exchange -- `--show-tags` says by how much.
- It comes from Alpine's testing repository (`ticker@testing`).
