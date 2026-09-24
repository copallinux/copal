# command:  lftp
# purpose:  A file-transfer shell for FTP, SFTP and HTTP: mirror folders, resume, queue.
# why:      The catalogue's terminal FTP client. It speaks SFTP over ssh too,
#           and mirrors a whole folder in either direction -- the tool for a
#           web host or an old server that offers only FTP.
# see:      rsync, curl, ssh

## Use
Connect, then work with `ls`, `cd`, `get` and `put` as in a shell. The
command to know is `mirror`: it copies a whole directory tree down, or up
with `-R`, sending only what changed.

## Examples
    lftp sftp://you@example.org          # connect over SFTP
    lftp ftp://ftp.example.org           # anonymous FTP
    lftp -u you ftp.example.org          # FTP with a password prompt
    lftp -c 'open sftp://you@host; mirror site/ ~/site'  # one command, then quit

    mirror REMOTE LOCAL      (in lftp) download a tree
    mirror -R LOCAL REMOTE   upload one
    pget -n 4 big.iso        a file in four parallel pieces
    get -c file              resume a download
    jobs  /  bye             running transfers / quit

## Options
-u USER[,PASS]   log in as USER
-p PORT          the port
-c COMMANDS      run these and exit
-f FILE          run a script of commands
-e COMMANDS      run these, then stay

## Notes
- Plain `ftp://` sends the password in the clear. Use `sftp://` wherever
  the server has ssh.
- `mirror` without `--delete` only adds and updates; with it, it
  removes what the source lacks. Try `mirror --dry-run` first.
- Settings go in `~/.config/lftp/rc` (or `~/.lftp/rc` if that exists),
  bookmarks with `bookmark add NAME`.
