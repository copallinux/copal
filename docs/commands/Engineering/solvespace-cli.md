# command:  solvespace-cli
# purpose:  SolveSpace from the command line: export and render .slvs models without the window.
# why:      The catalogue's scripted CAD: the SolveSpace window designs a part,
#           and this turns it into STL, a drawing or a picture in a Makefile.
# see:      admesh, solvespace

## Use
Name a command and the `.slvs` files to apply it to. `--output` is a
pattern: `%` becomes each input file's name.

## Examples
    solvespace-cli export-mesh --output %.stl part.slvs              # a mesh for a slicer
    solvespace-cli export-view --view top --output %-top.svg part.slvs   # a 2D drawing
    solvespace-cli thumbnail --output %.png --size 400x400 --view isometric part.slvs
    solvespace-cli regenerate part.slvs  # reload imports, regenerate, save

## Options
export-mesh          a triangle mesh (STL, OBJ...)
export-view          a 2D view (SVG, DXF, PDF...), --view VIEW
export-surfaces      exact surfaces (STEP)
thumbnail            a rendered picture, --size WxH
regenerate           reload, regenerate and save
-o, --output PAT     the output name: % is the input's name
-v, --view DIR       top, bottom, left, right, front, back, isometric
-t, --chord-tol N    how finely curves become straight segments

## Notes
- The output format follows the extension of `--output`: `.stl` or
  `.obj` for a mesh, `.svg`, `.dxf` or `.pdf` for a view.
- `--chord-tol` is in millimetres for exports: smaller is smoother and
  larger.
