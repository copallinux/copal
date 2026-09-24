# command:  sc-im
# purpose:  A spreadsheet in the terminal, with vim's keys: formulas, CSV, and Excel import.
# why:      The catalogue's spreadsheet for a machine with no desktop, or for a
#           quick sum over SSH. It opens CSV and XLSX, and writes both back.
# see:      vim, python3

## Use
Move between cells with vim's keys, type `=` to enter a number or a
formula, `<` or `>` for text. `:w` saves in its own format; CSV and
tab-separated files open and export directly.

## Examples
    sc-im                                # a new sheet
    sc-im budget.csv                     # open a CSV
    sc-im report.xlsx                    # import a spreadsheet
    sc-im --nocurses --quit_afterload data.csv   # print it, no screen

    =  @sum(B2:B10)    (in sc-im) a formula in the current cell
    <  >               a text label, left / right aligned
    e  E  x            edit the number / edit the text / clear the cell
    :e csv out.csv     export as CSV
    :w  :q             save / quit;  u  undo

## Options
--nocurses         no screen: print the sheet and read commands from stdin
--quit_afterload   leave after loading (with --nocurses: a print)
--sheet=SHEET      which sheet of an XLSX to open
--xlsx_readformulas  import formulas from XLSX, not only their values
--output=FILE      where --nocurses writes

## Notes
- Formulas use sc's functions with an `@`: `@sum`, `@avg`, `@max`,
  `@if`. Excel's `SUM()` spelling is not understood.
- It exports as well as imports: `:e xlsx FILE` for a spreadsheet
  program, `:e mkd FILE` for a Markdown table, `:e txt` for plain text.
- `:help` is the full manual, inside the program.
