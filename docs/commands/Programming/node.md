# command:  node
# purpose:  Node.js: run JavaScript outside the browser, with npm for its packages.
# why:      On Copal because Claude Code runs on it (stage 7 installs it when
#           Claude Code is chosen) and because a checkout builds with npm; the
#           store offers it for JavaScript work of your own.
# see:      npm, python3

## Use
Run a script, or start the prompt and type JavaScript. npm installs a
project's packages into its `node_modules`; `npm install -g` puts tools
in your own prefix, `~/.npm-global`, which is on PATH.

## Examples
    node                                 # the prompt; .exit to leave
    node app.js                          # run a script
    node -e 'console.log(2 ** 53)'       # one line
    node --watch server.js               # restart when the file changes
    npm init -y && npm install express   # a project and a package
    npm install -g prettier              # a tool, into ~/.npm-global

## Options
-e, --eval CODE    run CODE
-p, --print CODE   run CODE and print the result
-c, --check        check the syntax only
-i                 the prompt, even when stdin is not a terminal
--watch            restart on changes
--test             run the tests in the project

## Notes
- `npm install -g` never needs doas here: Copal sets npm's global prefix
  to `~/.npm-global` for your account (`/etc/profile.d/npm-global.sh`).
- Packages with native parts compile on install and need `build-base`
  and `python3`; a package shipping glibc binaries will not run on musl.
