# command:  octave
# purpose:  GNU Octave: numerical computing in a language compatible with MATLAB.
# why:      The catalogue's MATLAB-alike: matrices, linear algebra, signal
#           processing and plots, and most MATLAB scripts run unchanged.
# see:      python3, R, gnuplot, maxima

## Use
Type at the `>>` prompt, or run a `.m` script. Everything is a matrix;
`;` at the end of a line stops it printing the result.

## Examples
    octave                               # the prompt
    octave script.m                      # run a script
    octave --eval 'disp(inv([2 1; 1 3]))'   # one expression
    octave --no-gui                      # the terminal prompt, never a window

    A = [1 2; 3 4];     (at the prompt) a matrix
    x = A \ [5; 6]      solve A x = b
    plot(sin(0:0.1:6))  a plot, in a window
    pkg list            the installed packages;  exit  leave

## Options
--eval CODE     run CODE and exit
--no-gui        the command line, no window
-q, --quiet     no banner
-W, --no-window-system   no graphics at all (plots fail; for scripts)
--path DIR      add DIR to the function search path

## Notes
- Plots open a window, so they need the desktop. Over SSH, use
  `graphics_toolkit gnuplot` and `set terminal dumb` for ASCII, or
  `print -dpng plot.png` to save the figure.
- Octave-Forge packages (`pkg install -forge NAME`) build from source
  and need `build-base`; several are in Alpine as `octave-NAME`.
