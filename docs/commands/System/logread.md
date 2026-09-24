# command:  logread
# purpose:  Read BusyBox syslogd's in-memory log.
# why:      Alpine's usual answer to "where is the log" -- and on Copal the
#           wrong one: Copal's syslogd writes the file /var/log/messages, not
#           the in-memory buffer logread reads.
# see:      dmesg, rc-status, busybox

## Use
On an Alpine system whose syslogd keeps a circular buffer in memory
(started with `-C`), print it, or follow it. On Copal, read the file
instead: the same messages, kept across reboots.

## Examples
    tail -50 /var/log/messages           # Copal: the latest system messages
    tail -f /var/log/messages            # Copal: follow them
    grep sshd /var/log/messages          # one service's lines
    logread -f                           # elsewhere: follow the buffer

## Options
-f    follow: print new messages as they arrive
-F    the same, after printing the whole buffer first

## Notes
- On Copal `logread` answers "can't find syslogd buffer": syslogd runs
  with `SYSLOGD_OPTS="-t"` (see `/etc/conf.d/syslog`), which writes the
  file. That is expected, not a fault.
- `/var/log/messages` belongs to the group `wheel`, so an administrator
  reads it without `doas`.
- Kernel messages are not in it: read them with `doas dmesg`.
