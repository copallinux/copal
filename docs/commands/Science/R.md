# command:  R
# purpose:  The R language for statistics and graphics.
# why:      The catalogue's statistics environment: data frames, models, tests
#           and plots, with CRAN's twenty thousand packages behind it.
# see:      python3, octave, gnuplot

## Use
Type at the `>` prompt, or run a script with `Rscript`. Data frames hold
tables; `summary()`, `lm()` and `plot()` do most of the everyday work.

## Examples
    R                                    # the prompt
    Rscript analysis.R                   # run a script
    R -q -e 'summary(mtcars)'            # one expression
    R --vanilla                          # no saved workspace, no profiles

    d <- read.csv("data.csv")    (at the prompt) load a table
    summary(d)                   the statistics of each column
    fit <- lm(y ~ x, data=d)     a linear model;  summary(fit)
    install.packages("ggplot2")  a package from CRAN
    q()                          leave

## Options
-q, --quiet       no banner
-e EXPR           evaluate EXPR (with R -q -e)
--vanilla         no profile, no saved workspace
--no-save         do not save the workspace on exit
-f FILE           read commands from FILE

## Notes
- The system library is not writable: the first `install.packages()`
  offers a personal library in your home -- answer yes.
- Packages with C or Fortran compile from source on Alpine (no binary
  packages for musl) and need `build-base` and `gfortran`; the first
  install of a big one takes a while.
- `q()` asks whether to save the workspace; `n`, or it reloads into
  every later session.
