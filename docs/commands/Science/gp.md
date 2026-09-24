# command:  gp
# purpose:  PARI/GP: a calculator for number theory -- huge integers, primes, factoring, elliptic curves.
# why:      The catalogue's number-theory system: exact arithmetic on numbers
#           with thousands of digits, fast, at an interactive prompt.
# see:      maxima, Singular

## Use
Type an expression at the `?` prompt and get the answer. Integers are
exact at any size; `\p` sets the decimal precision for everything else.

## Examples
    gp                                   # the prompt
    echo 'factor(2^128+1)' | gp -q       # one computation, quietly
    gp -q script.gp                      # run a file

    factor(2^67 - 1)       (at the prompt) factor a number
    isprime(10^100 + 267)  is it prime?
    nextprime(10^50)       the next prime
    \p 100                 100 digits of precision;  Pi  then shows them
    ?factor                help on one function;  \q  quit

## Options
-q, --quiet         no banner
-s SIZE             the initial stack size
-p N                precompute primes up to N
--default KEY=VAL   set a default at start: --default realprecision=50

## Notes
- "the PARI stack overflows": it grows the stack itself up to
  `parisizemax`; for very large computations, `default(parisizemax,
  "2G")`.
- `?` alone lists the help sections; `??factor` is the long manual entry.
