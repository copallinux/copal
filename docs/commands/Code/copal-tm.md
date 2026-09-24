# command:  copal-tm
# purpose:  Copal's task manager: an instrument panel and a process browser in one terminal window.
# why:      The task manager on Copal's full install, built by copal-build from
#           its checkout: what the machine is doing, which process is doing it,
#           and a considered way to stop one.
# see:      htop, btop, copal-halt

## Use
The top half is the instrument panel -- CPU, memory, swap, temperature,
network, pressure; the bottom half is the process tree. Select a process
and press `k` to send it one signal, or `x` for the Halt plan: the
gentle signals first, the hard one last, with the reasons shown.

## Examples
    copal-tm                             # the panel and the browser, split
    copal-tm --view dashboard            # the instrument panel only
    copal-tm --view browser              # the process list only
    copal-tm --refresh 0.5               # tick twice a second
    copal-tm --dump-config > ~/.config/copal/taskman.conf   # a config to edit

    F1 F2 F3        (in the window) dashboard / split / browser
    Enter  i        the Inspector: attributes, contents, network, tools, access
    k  x            send one signal / the Halt plan
    /  s  t         filter / sort / tree
    T               the Transcript: every signal sent, and why
    ?  q            keys / quit

## Options
--view MODE        split, dashboard or browser
--refresh SECONDS  the tick, 0.25 to 10 (default 1.0)
--charset SET      auto, full, blocks or ascii
--color MODE       auto, truecolor or 16
--browser.sort KEY cpu, mem, pid, time, name or user
--theme NAME       copal or mono
--simulate         run against a simulated machine
--dump-config      print the effective configuration

## Notes
- `k` shows each signal's disposition -- whether the process catches,
  ignores or dies of it -- before you send it; the Halt plan uses those.
- The configuration is `~/.config/copal/taskman.conf`, `key = value`, and
  every key is also a flag of the same name.
- It degrades legibly: on a 16-colour console or an ASCII-only terminal
  it still draws, with `--charset ascii`.
