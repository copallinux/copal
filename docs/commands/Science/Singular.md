# command:  Singular
# purpose:  Computer algebra for polynomials: Gröbner bases, ideals, singularities.
# why:      The catalogue's polynomial-algebra system, the tool of commutative
#           algebra and algebraic geometry. The command has a capital S.
# see:      maxima, gp

## Use
Declare a ring -- the field, the variables, the ordering -- then work in
it with polynomials and ideals. Every statement ends with `;`.

## Examples
    Singular                             # the prompt (capital S)
    Singular -q script.sing              # run a file

    ring r = 0, (x,y,z), dp;       (at the prompt) rational coefficients, x y z
    ideal I = x2 - y, y2 - z;      an ideal (x2 is x^2)
    std(I);                        its Gröbner basis
    help std;                      help on a command
    quit;                          leave

## Options
-q, --quiet      no banner, and quit at the end of a file
-b, --batch      batch mode
--no-rc          do not read the .singularrc file
-c CMD           run CMD first

## Notes
- The command is `Singular`; `singular` is not found.
- In a ring declared with short variable names, `x2y` means `x^2*y`.
