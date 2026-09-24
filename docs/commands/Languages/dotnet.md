# command:  dotnet
# purpose:  The .NET 9 SDK: create, build and run C#, F# and VB programs.
# why:      The catalogue's .NET, wherever Microsoft builds it -- not on ARMv6
#           or 32-bit x86. C# console programs and web services run on a Pi.
# see:      pwsh, java

## Use
`dotnet new` makes a project from a template, `dotnet run` builds and runs
it, `dotnet publish` makes a folder to copy to another machine.

## Examples
    dotnet new console -o hello && cd hello   # a new C# console program
    dotnet run                           # build and run it
    dotnet add package Newtonsoft.Json   # a NuGet package
    dotnet publish -c Release -o out     # a release build into out/
    dotnet new list                      # the templates there are

## Options
new TEMPLATE     create a project (console, classlib, web, ...)
run              build and run the project here
build            build it
add package P    add a NuGet package
publish          produce a deployable folder
test             run its tests

## Notes
- It sends usage statistics to Microsoft unless
  `DOTNET_CLI_TELEMETRY_OPTOUT=1` is set; put the export in
  `~/.profile.local` to keep it.
- The first `dotnet new` or `run` is slow while it sets up; later ones
  are quicker.
