# command:  arduino-cli
# purpose:  The Arduino toolchain without the IDE: install board cores, compile sketches, upload them.
# why:      The store's Arduino: the IDE is Electron and Java and does not run
#           here, but everything it does underneath is this command -- boards,
#           libraries, compile, upload, serial monitor.
# see:      screen, make

## Use
Install the core for your board once, then compile and upload a sketch
folder. The board is named by its FQBN, such as `arduino:avr:uno`;
`board list` shows what is plugged in and its port.

## Examples
    arduino-cli core update-index && arduino-cli core install arduino:avr   # once, for Uno and Nano
    arduino-cli board list               # the boards plugged in, and their ports
    arduino-cli sketch new Blink         # a new sketch folder
    arduino-cli compile -b arduino:avr:uno Blink
    arduino-cli upload -b arduino:avr:uno -p /dev/ttyACM0 Blink
    arduino-cli monitor -p /dev/ttyACM0 -c baudrate=9600   # the serial monitor

## Options
core install CORE    install a board platform (arduino:avr, esp32:esp32...)
board list           connected boards and their ports
compile -b FQBN DIR  compile a sketch
upload -b FQBN -p PORT DIR   upload it
lib install NAME     install a library
monitor -p PORT      the serial monitor
config init          write a configuration file to edit

## Notes
- Uploading uses the serial port, which belongs to `dialout`; Copal adds
  you with it (`copal-store access`), then log in again.
- Other boards' cores need their URL first: `arduino-cli config add
  board_manager.additional_urls URL`, then `core update-index`.
- It comes from Alpine's testing repository (`arduino-cli@testing`).
