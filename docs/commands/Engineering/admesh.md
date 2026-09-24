# command:  admesh
# purpose:  Check an STL mesh, and repair it: close holes, fix normals, remove stray facets.
# why:      The catalogue's STL doctor: a model that a slicer rejects or prints
#           wrong usually has a hole or a flipped face, and admesh reports and
#           fixes both.
# see:      solvespace-cli

## Use
Run it on an STL to see its statistics and problems. With options it
repairs, scales, rotates or merges, and writes the result with
`--write-binary-stl` or `--write-ascii-stl`.

## Examples
    admesh part.stl                      # check: size, facets, errors found
    admesh -b fixed.stl part.stl         # repair everything, write binary STL
    admesh --scale=25.4 -b mm.stl inch.stl   # inches to millimetres
    admesh --x-rotate=90 -b up.stl part.stl  # stand it up

## Options
-b, --write-binary-stl=F   write the result as binary STL
-a, --write-ascii-stl=F    write it as ASCII STL
-f, --fill-holes           fill holes in the mesh
-d, --normal-directions    fix facets facing the wrong way
-u, --remove-unconnected   remove facets with no neighbours
-e, --exact                join edges that match exactly
--scale=FACTOR             scale the model
--x-rotate=DEG             rotate about X (also --y-rotate, --z-rotate)
--merge=FILE               add another STL into this one

## Notes
- With no repair options it runs all of them; name one or more to run
  only those.
- It reads both ASCII and binary STL; binary output is several times
  smaller.
