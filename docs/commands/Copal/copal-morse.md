# command:  copal-morse
# purpose:  Send text as Morse code, drill yourself on it, or print the table.
# why:      Alpine packages no Morse program at all, and Copal is a radio
#           amateur's machine too. This one is written for timing: it builds
#           the whole message as one sound file with sox, so the rhythm is
#           exact even on a slow board where starting a program per beep would
#           ruin it.
# see:      sox, play, direwolf

## Use
Give it text and it plays and prints the code. `-d` is the drill: it sends
five random letters, you type what you heard.

## Examples
    copal-morse cq cq de n0call          # send it, at 13 words per minute
    copal-morse -w 20 -f 700 sos         # faster, and higher
    copal-morse -q hello world           # print the dots and dashes only
    copal-morse -p                       # the table
    copal-morse -d                       # the drill (Ctrl-C to stop)
    copal-morse -w 5 -d                  # a beginner's drill

## Options
-w WPM      speed in words per minute (default 13)
-f HZ       tone in hertz (default 600)
-q          print the code, play nothing
-p          print the table and exit
-d          drill: it sends, you type
-h, --help  the usage

## Notes
- In the drill, Enter alone repeats the group and `?` shows it; it keeps
  score of right and wrong.
- Speed is by the standard word PARIS: at W words per minute a dot lasts
  1200/W milliseconds. Letters, digits and common punctuation are sent;
  anything else is skipped.
- It needs sox for sound (`doas apk add sox`); without it, it prints the
  code instead.
