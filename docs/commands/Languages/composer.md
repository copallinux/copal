# command:  composer
# purpose:  PHP's dependency manager: fetch the libraries a project needs, and autoload them.
# why:      Part of the catalogue's PHP 8.3 row, with Xdebug: for writing PHP
#           programs and trying frameworks on the Pi. The row installs PHP
#           for development, not as a public server.
# see:      php83

## Use
In a project, `composer require` adds a library and installs it into
`vendor/`; `composer install` installs exactly what `composer.lock`
records. Your code includes `vendor/autoload.php` once.

## Examples
    composer init                        # a composer.json for this folder
    composer require monolog/monolog     # add a library
    composer install                     # install what composer.lock says
    composer update                      # move to newer allowed versions
    composer create-project laravel/laravel app   # a new project from a package

## Options
init              create composer.json
require PKG       add and install a package
install           install from composer.lock
update            update within composer.json's limits
dump-autoload     regenerate the autoloader
create-project P  start a project from package P

## Notes
- Commit `composer.lock`: it is what makes `install` give everyone the
  same versions.
- PHP modules a library needs (`php83-mbstring`, `php83-pdo`...) are apk
  packages; `composer check-platform-reqs` names the missing ones.
