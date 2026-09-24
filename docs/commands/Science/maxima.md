# command:  maxima
# purpose:  Computer algebra: solve, simplify, differentiate, integrate -- exactly, with symbols.
# why:      The catalogue's symbolic mathematics: the answer as a formula, not a
#           number -- integrals, limits, series, systems of equations.
# see:      octave, gp, Singular, gnuplot

## Use
Type expressions at the `(%i1)` prompt, each ending with `;` (show the
result) or `$` (hide it). `%` is the last result. Everything stays exact
until you ask for a number with `float()`.

## Examples
    maxima                               # the prompt
    maxima --batch-string='integrate(x*sin(x), x);'   # one computation, then exit
    maxima -b work.mac                   # run a file of commands

    diff(x^3*sin(x), x);         (at the prompt) differentiate
    integrate(1/(1+x^2), x, 0, 1);   a definite integral: %pi/4
    solve([x+y=3, x-y=1], [x,y]);    a system of equations
    float(%pi);                  a number
    quit();                      leave

## Options
-b, --batch FILE        run FILE and exit
--batch-string=STR      run STR and exit
-q, --quiet             no banner
-r, --run-string=STR    run STR, then stay at the prompt

## Notes
- Every input ends with `;` or `$`. Without one, Maxima waits for more.
- `plot2d(sin(x), [x, 0, 6])` draws with gnuplot.
- It comes from Alpine's testing repository (`maxima@testing`).
