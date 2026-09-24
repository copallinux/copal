# command:  gnuplot
# purpose:  Plot functions and data files, in a window, to an image, or as text in the terminal.
# why:      The catalogue's plotter, and the one Octave, Maxima and ngspice draw
#           through. A plot of a data file is one line.
# see:      octave, maxima, ngspice, python3

## Use
`plot` a function or a file's columns. Where the plot goes is the
terminal setting: a window, a PNG or SVG file, or the text terminal
itself (`dumb`, or `sixelgd` in a terminal that shows sixel images).

## Examples
    gnuplot -p -e 'plot sin(x)'          # a window that stays open
    gnuplot -e 'set terminal dumb; plot sin(x)'   # as text, over SSH
    gnuplot -e "set terminal pngcairo; set output 'p.png'; plot 'data.txt' using 1:2 with lines"
    gnuplot script.gp                    # a file of commands
    gnuplot                              # the prompt

    plot 'data.csv' using 1:3 with lines   (at the prompt) columns 1 and 3
    set datafile separator ','             for CSV
    replot                                 draw again after a change

## Options
-e 'CMDS'    run the commands (separated by ;)
-p           persist: keep the window after gnuplot exits
-c FILE ARGS run FILE with arguments
-d           ignore any ~/.gnuplot initialisation file

## Notes
- The terminals this build has: `x11` (a window), `pngcairo`, `svg`,
  `sixelgd`, `kittycairo`, and `dumb`. `set terminal` lists them all.
- A CSV needs `set datafile separator ','`; otherwise columns are split
  on whitespace.
