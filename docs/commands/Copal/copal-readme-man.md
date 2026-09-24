# command:  copal-readme-man
# purpose:  Make a man page from a project's README.md, so `man PROGRAM` answers for programs built from source.
# why:      The programs in ~/code have READMEs and no man pages. This turns the
#           parts of a README that are about using the program into a proper
#           man page -- leaving out the badges, the build instructions and the
#           licence -- so the manual works for them like everything else.
# see:      copal-build, lowdown, man

## Use
copal-build runs it for every checkout it builds. Run it yourself to make
or preview a page: give the README and the program names, and it writes
roff to standard output.

## Examples
    copal-readme-man ~/code/staticstream/README.md sstr,ytq > sstr.1
    copal-readme-man ~/code/ascitty/README.md ascitty > /tmp/a.1; man -l /tmp/a.1
    copal-readme-man --markdown README.md ascitty   # what goes in, as Markdown

## Options
README NAME[,NAME...]      the page, as roff, on stdout
--markdown README NAME     the filtered Markdown instead, to review

## Notes
- It keeps the sections about using the program and drops the title,
  badges, images and HTML, and the sections a user of the installed
  program does not need: building, installing, downloading, licence,
  contributing, credits, status, roadmap, changelog and internals.
- The NAME line lists every program named; the description is the first
  sentence of the README's first paragraph of prose. The date is the
  README's last commit, so the same README makes the same page.
- A README's `##` becomes a section, its `###` a subsection. lowdown does
  the conversion (`doas apk add lowdown`).
