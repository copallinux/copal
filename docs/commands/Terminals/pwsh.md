# command:  pwsh
# purpose:  PowerShell: Microsoft's shell and scripting language, passing objects between commands.
# why:      The store's PowerShell, as on Windows: for scripts written for it,
#           for managing Windows and cloud systems from the Pi, and for
#           learning it where it is used at work.
# see:      dotnet, bash

## Use
Start it for its prompt, or run a script or one command. Its commands
are Verb-Noun (`Get-ChildItem`, `Get-Process`) and pass objects, not
text: a pipeline sorts and filters by property.

## Examples
    pwsh                                 # the prompt; exit to leave
    pwsh -File script.ps1                # run a script
    pwsh -c 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 5'
    pwsh -NoProfile -c '$PSVersionTable' # the version, without your profile

    Get-Help Get-ChildItem -Examples     (at the prompt) examples for a command
    Get-Command *Item*                   commands matching a word

## Options
-File FILE          run a script
-Command CMD        run CMD (-c)
-NoProfile          skip the profile scripts
-NoLogo             no banner
-Login              start as a login shell

## Notes
- Linux commands still work inside it, but they pass text: `ls | Sort-Object`
  sorts lines, not files. `Get-ChildItem` gives objects.
- Its telemetry is off only with `POWERSHELL_TELEMETRY_OPTOUT=1` set in
  the environment before it starts.
- Not on ARMv6 or 32-bit x86: its row is gated off there.
