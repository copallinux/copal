# command:  fpc
# purpose:  Free Pascal: a compiler for Pascal and Object Pascal, Turbo Pascal and Delphi dialects included.
# why:      The catalogue's Pascal: old Turbo Pascal programs and new Object
#           Pascal ones compile here, quickly, into small native programs.
# see:      gcc

## Use
Give it a `.pas` file; it writes a program named after it. A mode switch
chooses the dialect when compiling older code.

## Examples
    fpc hello.pas                        # compile; run with ./hello
    fpc -O2 prog.pas                     # optimised
    fpc -Mtp old.pas                     # in Turbo Pascal mode
    fpc -Mdelphi unit.pas                # in Delphi mode
    fpc -g prog.pas                      # with debug information

## Options
-o<NAME>      the output name (no space: -ohello)
-O1 / -O2     optimisation levels
-g            debug information
-M<MODE>      dialect: fpc, objfpc, tp, delphi
-Fu<DIR>      where to find units
-h            every option

## Notes
- Options take their value with no space: `-ohello`, `-Fu./units`.
- It comes from Alpine's testing repository (`fpc@testing`).
