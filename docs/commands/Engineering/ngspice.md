# command:  ngspice
# purpose:  SPICE circuit simulation: transient, AC and DC analysis of a netlist.
# why:      The catalogue's circuit simulator, the standard open one: check a
#           filter, an amplifier or a power supply before building it.
# see:      gnuplot, python3

## Use
Describe the circuit as a netlist -- components, the nodes they join,
their values -- and the analyses to run. Interactively it plots results
as ASCII; in batch mode it writes them for another program to plot.

## Examples
    ngspice rc.cir                       # load it, then 'run' and 'plot v(out)'
    ngspice -b rc.cir                    # batch: run and print, no prompt
    ngspice -b -r out.raw rc.cir         # batch, results to a rawfile
    ngspice -b -o log.txt rc.cir         # batch, output to a log

    run            (at the prompt) run the analyses in the netlist
    plot v(out)    plot a node's voltage
    print v(out)   print it as numbers
    quit           leave

## Options
-b, --batch          run and exit
-r, --rawfile FILE   write the results to FILE
-o, --output FILE    write the output to FILE
-i, --interactive    stay interactive even with a file on stdin
-n, --no-spiceinit   ignore .spiceinit files

## Notes
- A netlist's first line is its title and is never read as a component
  -- a first component there silently disappears.
- `gnuplot out v(out)` at the prompt draws the plot with gnuplot,
  which the catalogue's Science section installs.
