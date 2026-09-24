# command:  gfortran
# purpose:  The GNU Fortran compiler: FORTRAN 77 through Fortran 2018.
# why:      Stage 7's Fortran, for numerical code old and new -- and the
#           compiler R and SciPy-style builds need for their Fortran parts.
# see:      gcc, gdb, make

## Use
Compile `.f90` (free form) or `.f` (fixed form, FORTRAN 77) files as gcc
compiles C. The standard is chosen with `-std`.

## Examples
    gfortran -Wall -g hello.f90 -o hello         # compile, warnings on
    gfortran -O2 -std=f2018 model.f90 -o model   # optimised, Fortran 2018
    gfortran -std=legacy old.f -o old            # a FORTRAN 77 program
    gfortran -c util.f90 && gfortran main.f90 util.o -o prog   # modules, then link
    gfortran -fcheck=all -g prog.f90             # run-time bounds checking

## Options
-o FILE          the output
-g               debug information
-Wall            warnings
-std=STD         legacy, f95, f2003, f2008, f2018
-fcheck=all      check array bounds and more at run time
-ffree-form / -ffixed-form   override what the extension says

## Notes
- A module's `.mod` file is written where it is compiled: compile the
  modules before the programs that `use` them.
- Optimisation levels (`-O2`, `-O3`) are gcc's, shared by every
  language it compiles: `man gcc` documents them.
- `-fcheck=all` finds the out-of-bounds errors that are silent
  otherwise; keep it for debugging, it slows the program.
