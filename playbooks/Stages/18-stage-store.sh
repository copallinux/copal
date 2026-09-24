# playbook: stage-store
# source:   copal
# origin:   stage
# stage:    18
# category: Store
# step:     The Copal Store, and OpenShot compiled
# weight:   6
# levels:   medium full
# summary:  Installs Copal Apps and its starter programs, and at the full level queues thirteen more
#           for the first desktop login. The slideshow shows them arriving.

stage_store() {
    say "Stage 18: the Copal Store"

    # The window is yad, the terminal fallback dialog. Both small. Copal Apps,
    # the GTK window over the same store, needs Python's GTK 3 bindings, which
    # copal-gui has already brought on every desktop level.
    add_optional yad dialog py3-gobject3 gtk+3.0

    mkdir -p /usr/local/bin /usr/local/share/applications
    cat > /usr/local/bin/copal-store <<'COPALSTORE'
#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
#
# copal-store -- find a good program by what it does, and install it.
#
#   copal-store                    the store window (yad), or menus in a terminal
#   copal-store list [SECTION]     every program: status, section, id, name
#   copal-store sections           the sections, and how many programs in each
#   copal-store info ID            what it is, where it comes from, how it installs
#   copal-store install ID...      install (root: doas is asked for)
#   copal-store manpages PKG...    the man pages of these packages (their origins' -doc)
#   copal-store access [USER]      the groups installed programs need (plugdev, wireshark,
#                                  dialout, cdrom, users), and their device and file fixes
#   copal-store optionals [PKG...|--installed]  the plugins and helpers a package wants;
#                                  with --installed, add them for everything installed
#   copal-store remove ID...       and take it away again
#   copal-store recipes            the programs built from GitHub source here
#   copal-store playbook ID        one program in full: about, source, needs, steps, status, last build
#   copal-store rows               every program, one line each, its status last (for a window)
#   copal-store pending ID...      the ones of those ids not installed yet
#   copal-store bundle [NAME]      the bundles, or the program ids in one (starter, full-monty)
#   copal-store events [N]         the last N progress events (JSON, one per line)
#   copal-store summary            what each build did: result, size, sources, absences
#   copal-store log ID             one build's full log
#   copal-store section NAME       the window for one section
#   copal-store show ID            the window for one program, to link to
#
# WHAT THIS IS. Pi-Apps, ported: the same idea -- a short, curated shelf of
# programs a desktop user actually wants, each with a sentence saying what it
# is, so a name you half remember can be found by what it does -- rebuilt for
# Alpine. Pi-Apps installs with Debian packages and upstream binaries built
# for glibc; neither exists here. What does exist is two sources, taken in
# this order:
#
#   1. The program's own source on GitHub, compiled on this machine. A recipe
#      below pins a release tag and its SHA-256, carries whatever patch musl
#      needed, and installs under /usr/local through a staging directory, so
#      the list of files it put there is exact and 'remove' can take them all
#      away again. Some "run" rather than compile: a Java jar, a LOVE game.
#   2. An Alpine package, main, community or edge/testing, where Alpine
#      already builds the program -- no reason to compile what apk ships.
#
# Flathub is deliberately not a source here: the one Flathub program Copal
# carries (Brave) stays in the catalogue where it always was. Programs that
# only exist as a Flatpak, a glibc binary or a Windows program are left out
# of the table, and docs/copal-store.md says which and why.
#
# THE SHELF IS TWO TABLES. The catalogue (/usr/local/share/copal/catalogue),
# which stage 12 installs from and copal-menu is built from, and the store's
# own table below, which nothing installs unless someone asks. The window
# shows both; the store's rows carry a description, the catalogue's carry it
# in their label. The two never list the same program: tools/copal-store-check
# fails if they do.
#
# THE TABLE'S FIELDS are the catalogue's, plus two:
#
#   section|label|install|bin|mode|gate|description|home
#
#   install   apk names, 'name@testing' for edge/testing, or 'recipe@source'
#   bin       the command it answers to, or '-' for a font (nothing to run)
#   mode      x window, t terminal program, h command-line tool, - nothing
#   gate      the catalogue's architecture gate: *, 64, !v6, !x32 ...
#   home      where the source lives
#
# Each program's id is its bin, or its first package when bin is '-'.
set -u

PREFIX="${COPAL_STORE_PREFIX:-/usr/local}"
STATE="${COPAL_STORE_STATE:-/var/lib/copal/store}"
CACHE="${COPAL_STORE_CACHE:-/var/cache/copal-store}"
WORK="${COPAL_STORE_WORK:-/usr/local/src/copal-store}"
LOGDIR="${COPAL_STORE_LOGDIR:-/var/log/copal-store}"
# The event stream (docs/playbooks-plan.md, II): one JSON object per line for
# every run, program and step, which the progress views read and never write.
EVENTS="${COPAL_EVENTS:-/var/log/copal/events}"
CATFILE="${COPAL_CATFILE:-/usr/local/share/copal/catalogue}"
APKDB="${COPAL_APKDB:-/lib/apk/db/installed}"

have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '    warning: %s\n' "$*" >&2; }
die()  { printf 'copal-store: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------ table ---
# >>> playbooks: table -- generated from playbooks/ by 'make sync-playbooks'; edit those, not this
store_table() {
    cat <<'STORETABLE'
Appearance|Caskaydia Cove NF (Cascadia Code, Nerd cut)|font-cascadia-code-nerd|-|-|*|Microsoft's coding font, Cascadia Code, with the Nerd Font icons added. It has the glyphs that prompt themes and status bars draw with.|https://github.com/ryanoasis/nerd-fonts
Appearance|Color Emoji font (Noto)|font-noto-emoji|-|-|*|Google's colour emoji font, for every program on the machine. Chat messages and web pages show faces instead of empty boxes.|https://github.com/googlefonts/noto-emoji
Appearance|Oh My Posh (prompt themes)|ohmyposh@source|oh-my-posh|h|*|Over a hundred ready-made prompt themes for bash, zsh and fish, showing git state, battery, time and more. Themes are in /usr/local/share/oh-my-posh/themes; pair it with Caskaydia Cove NF.|https://github.com/JanDeDobbeleer/oh-my-posh
Appearance|Starship (shell prompt)|starship|starship|h|*|A fast prompt for any shell showing the git branch, the language version and how long the last command took. The maintained successor to Powerline-Shell.|https://github.com/starship/starship
Audio|Ardour (recording studio)|ardour@source|ardour9|x|64|A full digital audio workstation: record many tracks at once, edit and mix them with plugins and automation, and master the result. MIDI and virtual instruments too.|https://ardour.org
Browsers|Browsh (the web in a terminal)|browsh@source|browsh|t|!v6|A modern web browser inside a terminal, or over SSH. A headless Firefox renders each page and Browsh draws it in text and colour blocks, video included.|https://github.com/browsh-org/browsh
Browsers|Epiphany (GNOME Web)|epiphany|epiphany|x|*|GNOME's web browser, clean and built on WebKit. It can turn any site into an app window of its own.|https://gitlab.gnome.org/GNOME/epiphany
Browsers|Firefox (rapid release)|firefox|firefox|x|!v6|Mozilla's current Firefox, updated every four weeks. The catalogue carries Firefox ESR, the slower-moving branch.|https://github.com/mozilla-firefox/firefox
Browsers|LibreWolf (private Firefox)|librewolf|librewolf|x|!v6,!x32|Firefox with the telemetry removed and uBlock Origin built in. It is private by default, with no settings to hunt for.|https://codeberg.org/librewolf
Chat|Caprine (Facebook Messenger)|caprine@testing|caprine|x|64|An unofficial desktop app for Facebook Messenger. It has a dark mode and none of the Facebook feed around it.|https://github.com/sindresorhus/caprine
Chat|Signal|signal-desktop@testing|signal-desktop|x|64|End-to-end encrypted messages and calls. Link it to the Signal app on your phone.|https://github.com/signalapp/Signal-Desktop
Chat|Telegram|telegram-desktop|Telegram|x|*|The official Telegram desktop client. Chats, channels and file transfers of any size, in step with your phone.|https://github.com/telegramdesktop/tdesktop
Code|ASCITTY (raytraced ASCII city)|ascitty@clone|ascitty|t|*|A raytraced city built entirely of typeable characters, rendered in real time on a colour terminal. A taxi game is inside it, and the same city runs on a Commodore Plus/4.|https://github.com/vonglurt/ascitty
Code|birdshot (bird and sky camera)|birdshot@clone|birdshot-gui|x|*|Bird and sky capture for the Raspberry Pi HQ Camera: a C++17 camera pipeline with a Qt window over it. Copal's camera command uses it first when it is there.|https://github.com/vonglurt/birdshot
Code|birdshot (camera, command line)|birdshot@clone|birdshot|h|*|The birdshot pipeline without its window, for capture from a script or over SSH. The same program the window drives.|https://github.com/vonglurt/birdshot
Code|Codex of Conquest (adventure RPG)|codexofconquest@clone|codexofconquest|x|*|A whole adventure RPG in one HTML file: combat, a world map, quests, saves and eight acts of story. Here it is served from the checkout and opened in the browser.|https://github.com/vonglurt/codexofconquest
Code|copal-tm (task manager)|copal-tm@clone|copal-tm|t|*|An instrument panel and a process browser in one terminal window. The task manager for Copal's full install, one Rust crate with no dependencies.|https://github.com/vonglurt/copal-tm
Code|Gonex (Team Yodacon's game)|gonex@clone|gonex|x|*|Team Yodacon's game, written in Go on the Ebitengine engine. A port of the 2005 Konex engine, built from its own checkout.|https://github.com/yodacon/gonex
Code|orrery (the fleet's console)|orrery@clone|orrery|t|*|The console for a fleet of Copal machines: the wall, the seat and the museum interface. It sees every machine in the room and acts on them.|https://github.com/vonglurt/orrery
Code|radbeeper (Geiger counter panel)|radbeeper@clone|radbeeper-gui|x|*|The instrument panel for a GQ GMC-320 Plus Geiger counter: two dials, a live chart and a log, from one or two tubes at once. It also pulls the history the counter recorded while unattended.|https://github.com/vonglurt/radbeeper
Code|radbeeper (Geiger counter, terminal)|radbeeper@clone|radbeeper|t|*|The same counter in a terminal: probe finds it, watch shows five time constants at once, and log pull downloads its stored history. The command the panel is built on.|https://github.com/vonglurt/radbeeper
Code|sstr (record and replay streams)|staticstream@clone|sstr|h|*|Records a stream into a .sstr file with its order, pace and damage tolerance intact, and plays it back. sstr export turns a folder of them into ordinary files.|https://github.com/vonglurt/staticstream
Code|sstr-workspace (stream archive)|staticstream@clone|sstr-workspace|t|*|The terminal Workspace over the archive and the download queue in one browser. Play, verify, export and read a capture on one key each.|https://github.com/vonglurt/staticstream
Code|UR FINKEL (the Royal Game of Ur)|urfinkel@clone|urfinkel|x|*|The Royal Game of Ur for the Commodore Plus/4, written in C and 6502 assembly. It runs here in VICE's Plus/4 emulator.|https://github.com/vonglurt/urfinkel
Code|Yodacon (the plugin, the suites, the engines)|yodacon@clone|-|-|*|Team Yodacon's centre: the 1997 ConEx plugin, its exporters and test suites, with the game and the 2005 engine it ports as submodules. Its Makefile round-trips the plugin and builds the game.|https://github.com/yodacon/yodacon
Code|ytq (download queue)|staticstream@clone|ytq|t|*|A download queue that watches the clipboard: Super+Shift+Y queues the copied link, and ytq run fetches it. What it downloads is kept as Static Stream.|https://github.com/vonglurt/staticstream
Creative|darktable (raw photo developer)|darktable@source|darktable|x|64|A darkroom for camera raw files: exposure, colour, lens correction and masks, applied without touching the original. Its lighttable sorts, rates and tags a whole shoot.|https://github.com/darktable-org/darktable
Creative|Kolourpaint (simple paint)|kolourpaint|kolourpaint|x|!v6|KDE's paint program, in the spirit of MS Paint. Draw, crop, resize and save, with nothing to learn first.|https://invent.kde.org/graphics/kolourpaint
Creative|Pencil2D (hand-drawn animation)|pencil2d@source|pencil2d|x|64|Traditional frame-by-frame animation with onion skins, in bitmap or vector layers, with sound, exported to video or GIF. Simple enough to start in five minutes.|https://github.com/pencil2d/pencil
Creative|Pixelorama (pixel art)|pixelorama@source|pixelorama|x|!v6|A pixel-art editor and sprite animator. Layers, onion skins, tile mode and palettes, exporting to PNG, GIF and sprite sheets.|https://github.com/Orama-Interactive/Pixelorama
Creative|Shotwell (photo library)|shotwell|shotwell|x|*|A photo library that imports from a camera or a folder and sorts by date and event. Quick fixes are built in: crop, straighten, red-eye.|https://gitlab.gnome.org/GNOME/shotwell
Crypto|Feather Wallet (Monero)|feather-wallet@testing|feather|x|*|A small, fast Monero wallet. It connects to a remote node, so there is no blockchain to download.|https://github.com/feather-wallet/feather
Crypto|Monero GUI|monero-gui@testing|monero-wallet-gui|x|!v6|The Monero project's own wallet. It can run a full node on this machine, trusting nobody else's.|https://github.com/monero-project/monero-gui
Discs|K3b (CD/DVD/Blu-ray burner)|k3b|k3b|x|!v6|KDE's disc burner for CDs, DVDs and Blu-ray. Data discs, audio CDs from music files, disc copies and ISO images, verified after writing.|https://invent.kde.org/multimedia/k3b
Documents|FocusWriter (distraction-free writing)|focuswriter@source|focuswriter|x|*|A full-screen writing window with nothing in it but the text: themes, daily goals, timers and alarms, typewriter sounds, and a spell checker. Opens and saves plain text, RTF, ODT and DOCX.|https://github.com/gottcode/focuswriter
Emulation|KRetro (Libretro front end, early)|kretro@source|kretro|x|64|KDE's front end for Libretro emulator cores, with a game library for the desktop, a TV or a phone. It is its first release and a work in progress, so expect gaps.|https://invent.kde.org/games/kretro
Emulation|QEMU (PC emulator)|qemu-system-x86_64 qemu-ui-gtk|qemu-system-x86_64|h|64|Emulates a whole x86_64 PC in a window. Boot another operating system from an ISO without leaving this one.|https://gitlab.com/qemu-project/qemu
Emulation|Waydroid (Android)|waydroid|waydroid|h|!v6|Runs a full Android system in a container. Its apps open as ordinary windows on this desktop.|https://github.com/waydroid/waydroid
Engineering|LibreCAD (2D CAD)|librecad@source|librecad|x|64|Precise 2D drawing: floor plans, parts and schematics, in layers and blocks. It reads and writes DXF, and reads DWG.|https://github.com/LibreCAD/LibreCAD
Engineering|OpenSCAD (programmer's 3D CAD)|openscad|openscad|x|!v6,!v7,!a64|Solid 3D models written as code -- cubes, cylinders, unions and differences -- for 3D printing. Alpine builds it for x86 only.|https://github.com/openscad/openscad
Files|Czkawka (find duplicates)|czkawka-gui czkawka|czkawka_gui|x|*|Finds duplicate files, empty folders, big files, similar images and videos, and broken files, then deletes or moves the ones you tick. czkawka_cli does the same from a terminal.|https://github.com/qarmin/czkawka
Files|fdupes (find duplicates)|fdupes|fdupes|h|*|Finds duplicate files by size, then checksum, then byte by byte. fdupes -r ~/Pictures lists them, and -d asks which copy to keep.|https://github.com/adrianlopezroche/fdupes
Files|jdupes (faster fdupes)|jdupes@testing|jdupes|h|*|A faster fork of fdupes, with the same options. It can replace duplicates with hard links, reclaiming space without deleting a name.|https://codeberg.org/jbruchon/jdupes
Files|rdfind (duplicates across folders)|rdfind|rdfind|h|*|Finds duplicates across several folders and ranks which copy is the original. It reports the rest, or replaces them with links.|https://github.com/pauldreik/rdfind
Games|Amiberry (Amiga emulator)|amiberry@source|amiberry|x|64|An Amiga 500 to 4000 emulator tuned for ARM boards, with WHDLoad for games from hard-disk images. Needs Kickstart ROMs for most software; AROS boots without them.|https://github.com/BlitterStudio/amiberry
Games|Armagetron Advanced (light cycles)|armagetronad@testing|armagetronad|x|*|Tron's light cycles in 3D: steer at right angles, leave a wall behind you, and make the others crash into it. Against the computer or online.|https://gitlab.com/armagetronad/armagetronad
Games|AstroMenace (3D space shooter)|astromenace@source|astromenace|x|64|A hardcore 3D shoot-'em-up: fifteen levels of enemies and bosses. The money you collect buys weapons and armour between levels.|https://github.com/viewizard/astromenace
Games|C-Dogs SDL (run-and-gun)|cdogs-sdl@testing|cdogs-sdl|x|*|An overhead run-and-gun for up to four players on one screen. Campaigns, deathmatch and a level editor, in the style of the 1990s DOS original.|https://github.com/cxong/cdogs-sdl
Games|Celeste Classic (PICO-8 platformer)|ccleste@source|ccleste|x|64|The original Celeste, a precise little platformer from a 2015 game jam, in a C port. Arrow keys, Z to jump, X to dash.|https://github.com/lemon32767/ccleste
Games|Crispy Doom (with Freedoom)|crispy-doom@testing freedoom|crispy-doom|x|*|Chocolate Doom's faithfulness at twice the resolution, with widescreen and the limits lifted. Plays Freedoom out of the box, or your own DOOM.WAD.|https://github.com/fabiangreffrath/crispy-doom
Games|DDNet (DDraceNetwork)|ddnet@source|DDNet|x|64|Cooperative Teeworlds: a team of tiny gunners hooks and jumps through puzzle maps together. Thousands of maps, online or on a LAN.|https://github.com/ddnet/ddnet
Games|Descent 1 (shareware, DXX-Rebirth)|dxx@source|d1x-rebirth|x|64|The 1995 shooter flown in six degrees of freedom through mines taken over by robots. The shareware episode; copy the full game's files into ~/.d1x-rebirth to play the rest.|https://github.com/dxx-rebirth/dxx-rebirth
Games|Descent 2 (demo, DXX-Rebirth)|dxx@source|d2x-rebirth|x|64|Descent's sequel: more robots, a guide-bot, afterburners. The demo levels; the full game's files go in ~/.d2x-rebirth. Installed together with Descent 1.|https://github.com/dxx-rebirth/dxx-rebirth
Games|DevilutionX (Diablo)|devilutionx@source|devilutionx|x|64|Diablo, the 1996 dungeon crawler, on its reconstructed engine: widescreen, controller support and quality-of-life fixes. Plays the free shareware episode as installed; copy DIABDAT.MPQ from the CD or GOG into ~/.local/share/diasurgical/devilution for the whole game.|https://github.com/diasurgical/devilutionX
Games|Dolphin (GameCube and Wii emulator)|dolphin-emu|dolphin-emu|x|64|Plays GameCube and Wii games from your own disc images, often at a higher resolution than the console managed. Needs a fast GPU; a Pi 5 runs the lighter games.|https://github.com/dolphin-emu/dolphin
Games|Doom 3 (dhewm3 engine)|dhewm3@testing|dhewm3|x|*|The Doom 3 engine, open-sourced by id and kept alive as dhewm3. Bring the game's base/ folder from the demo or a copy you own.|https://github.com/dhewm/dhewm3
Games|Endless Sky (space trading)|endlesssky@source|endless-sky|x|64|Start with a small ship and a little money in a galaxy of trade routes, pirates and alien empires: haul cargo, take jobs, fight, and follow the main story when you are ready. In the spirit of Escape Velocity.|https://github.com/endless-sky/endless-sky
Games|Extreme Tux Racer|extremetuxracer@testing|etr|x|!v6|Tux slides downhill on his belly through snowy courses. Collect herring and race the clock.|https://sourceforge.net/projects/extremetuxracer/
Games|FCEUX (NES emulator)|fceux@testing|fceux|x|!v6|A Nintendo Entertainment System emulator for ROM files. Save states, rewind, and the debugging tools speedrunners use.|https://github.com/TASEmulators/fceux
Games|Friday Night Funkin' Rewritten (LOVE)|funkin@source|funkin-rewritten|x|*|The rhythm game where you out-sing your girlfriend's father, arrow keys to the beat. Rebuilt on the LOVE engine.|https://github.com/HTV04/funkin-rewritten
Games|Godot (game engine)|godot@testing|godot|x|!v6|A complete engine and editor for 2D and 3D games, scripted in GDScript. The engine Pixelorama is written in.|https://github.com/godotengine/godot
Games|Heroes 2 (fheroes2 engine)|fheroes2@testing|fheroes2|x|*|Heroes of Might and Magic II rebuilt as free software. Plays the free demo or the original game's data.|https://github.com/ihhub/fheroes2
Games|Kapman (Pac-Man)|kapman|kapman|x|!v6|KDE's Pac-Man: eat every pill in the maze while four ghosts hunt you. An energiser turns the tables for a few seconds.|https://apps.kde.org/kapman/
Games|KMahjongg (mahjong solitaire)|kmahjongg@source|kmahjongg|x|!v6|Mahjong solitaire: clear the board by matching pairs of free tiles. Dozens of layouts and tile sets, with a hint when you are stuck.|https://apps.kde.org/kmahjongg/
Games|Knights (chess)|knights gnuchess|knights|x|!v6|KDE's chess board: play against a chess engine, a friend at the same machine, or opponents online. GNU Chess comes with it as the engine to play.|https://apps.kde.org/knights/
Games|Konquest (galactic strategy)|konquest@source|konquest|x|!v6|KDE's galactic strategy game: send fleets from planet to planet and take the galaxy, against the computer or friends sharing one screen. Every planet you hold builds more ships each turn, so a game is a few minutes of planning and one good gamble.|https://apps.kde.org/konquest/
Games|KReversi (Othello)|kreversi@source|kreversi|x|!v6|Reversi, also called Othello, against the computer at several levels. Outflank the other colour's stones to turn them to yours.|https://apps.kde.org/kreversi/
Games|KSnakeDuel (light-cycle duel)|ksnakeduel@source|ksnakeduel|x|!v6|A snake duel in the spirit of Tron's light cycles: steer so the other runs into a wall or a trail first. Two players at one keyboard, or one against the computer.|https://apps.kde.org/ksnakeduel/
Games|KSpaceDuel (space combat)|kspaceduel@source|kspaceduel|x|!v6|Two spaceships orbit a sun and fight it out while gravity pulls at everything. Thrust, turn and fire, for two players or one against the computer.|https://apps.kde.org/kspaceduel/
Games|Kubrick (3D Rubik's Cube)|kubrick@source|kubrick|x|!v6|A Rubik's Cube in 3D: turn the faces with the mouse until every side is one colour. Cubes of other sizes and shapes, and demonstrations of the classic solutions.|https://apps.kde.org/kubrick/
Games|Marathon (the free trilogy, Aleph One)|alephone@source|marathon|x|64|Bungie's 1990s first-person shooters Marathon, Marathon 2 and Marathon Infinity, released free and played on Aleph One, the engine built from Bungie's source. Three launchers: marathon, marathon2, marathon-infinity.|https://github.com/Aleph-One-Marathon/alephone
Games|Minecraft Java (Prism Launcher)|prismlauncher|prismlauncher|x|*|Runs Minecraft: Java Edition, signed in with your own account. Each modpack gets its own separate instance.|https://github.com/PrismLauncher/PrismLauncher
Games|Moon Buggy (terminal)|moon-buggy@testing|moon-buggy|t|*|Drive a buggy across the moon in the terminal, jumping the craters as they come. Space jumps.|https://www.seehuhn.de/pages/moon-buggy.html
Games|Naev (space sandbox)|naev@source|naev|x|64|A 2D space trading and combat game with a large written story: fly, trade, take missions and join factions across hundreds of systems. Inspired by Escape Velocity.|https://github.com/naev/naev
Games|Naval Battle (battleships)|knavalbattle|knavalbattle|x|!v6|KDE's Naval Battle, the game of battleships: hide your fleet and sink the other side's by calling shots on a grid. Play the computer, or a friend over the network.|https://apps.kde.org/knavalbattle/
Games|OpenRCT2 (RollerCoaster Tycoon 2)|openrct2|openrct2|x|*|Builds theme parks and their rollercoasters, rebuilt as free software with bigger parks and online play. Needs the original RollerCoaster Tycoon 2 files (GOG or Steam).|https://github.com/OpenRCT2/OpenRCT2
Games|OpenTyrian (Tyrian 2000)|opentyrian@source|opentyrian|x|64|The 1995 vertical shooter Tyrian, freeware since 2004, on its open-source engine: a story campaign, an arcade mode, and ship upgrades bought between levels. Arrow keys to fly, Space to fire.|https://github.com/opentyrian/opentyrian
Games|Pac-Man (SDL clone)|pacman@source|pacman-game|x|64|A faithful Pac-Man for the desktop: eat the dots, dodge the four ghosts. Arrow keys.|https://github.com/ebuc99/pacman
Games|PPSSPP (PSP emulator)|ppsspp|PPSSPPQt|x|!v6,!v7|A PlayStation Portable emulator. Your own ISO files play upscaled to the screen you have.|https://github.com/hrydgard/ppsspp
Games|PyChess|pychess@source|pychess|x|*|Chess against the computer, with Stockfish installed alongside. Play online at FICS and Lichess too, with opening books, puzzles and lessons.|https://github.com/pychess/pychess
Games|Quakespasm (Quake engine)|quakespasm@testing|quakespasm|x|*|The original Quake, played faithfully on a modern engine. Needs Quake's id1/pak0.pak -- the shareware episode's is free; run it as quakespasm -basedir DIR, with the id1 folder in DIR.|https://github.com/sezero/quakespasm
Games|Sauerbraten (Cube 2 shooter)|sauerbraten@testing|sauerbraten|x|!v6|A fast arena shooter with a map editor built into the game, so maps can be built together while playing. About 1 GB installed.|http://www.sauerbraten.org/
Games|Sonic Robo Blast 2|srb2@testing|srb2|x|!v6,!v7|A 3D Sonic game made by fans on the Doom Legacy engine. Play as Sonic, Tails, Knuckles and more, with thousands of add-ons.|https://git.do.srb2.org/STJr/SRB2
Games|SuperTuxKart|supertuxkart|supertuxkart|x|!v6|Kart racing with Tux and friends: story mode, battle arenas, and online races. About 800 MB installed.|https://github.com/supertuxkart/stk-code
Games|Taisei (bullet hell)|taisei@source|taisei|x|64|A Touhou Project fan game: a vertical shoot-'em-up of dense, patterned bullet storms, six stages with a story, and practice modes. Arrow keys, Z to shoot, X for a bomb, Shift to focus.|https://github.com/taisei-project/taisei
Games|The Powder Toy (falling sand)|powder-toy@testing|powder|x|*|A falling-sand physics sandbox of powders, liquids, gases and electronics. Pour, burn, freeze and wire them, with pressure and heat simulated.|https://github.com/The-Powder-Toy/The-Powder-Toy
Games|VCMI (Heroes 3 engine)|vcmi@testing|vcmilauncher|x|64|Heroes of Might and Magic III rebuilt as free software, with larger maps and mods. Needs the original game's files; the launcher imports them from the GOG installer.|https://github.com/vcmi/vcmi
Games|Warzone 2100 (real-time strategy)|warzone2100@testing|warzone2100|x|64|A 3D real-time strategy game after a nuclear war: research 400 technologies and design your own units from them. Campaign, skirmish and online play.|https://github.com/Warzone2100/warzone2100
Games|X-Moto (motocross physics)|xmoto@testing|xmoto|x|*|A 2D motocross game where the physics is the point. Lean, brake and flip the bike to reach every strawberry, then the flower.|https://github.com/xmoto/xmoto
Games|Xonotic (arena shooter)|xonotic-sdl|xonotic-sdl|x|!v6|A fast arena first-person shooter in the Quake tradition, with bots for playing offline. About 1.2 GB installed.|https://gitlab.com/xonotic/xonotic
Graphics|Skanlite (scanner)|skanlite|skanlite|x|!v6|KDE's scanner program: preview, pick the area, and save the scan as an image. A current stand-in for QuiteInsane, the Qt front end to SANE.|https://invent.kde.org/graphics/skanlite
Graphics|XSane (scanner, every SANE option)|xsane@testing|xsane|x|*|The classic scanning front end to SANE, with every option the scanner has. Batch scans, colour correction, and save, copy, fax or email.|http://www.xsane.org
Internet|SpeedTest-CLI|speedtest-cli|speedtest-cli|h|*|Measures the connection's download speed, upload speed and ping. It tests against the nearest speedtest.net server, from a terminal.|https://github.com/sivel/speedtest-cli
Multimedia|Easy Effects|easyeffects|easyeffects|x|*|An equaliser, compressor and noise remover for all the machine's sound. It works on everything played or recorded, through PipeWire.|https://github.com/wwmm/easyeffects
Multimedia|FreeTube (private YouTube)|freetube@testing|freetube|x|64|Watches YouTube without an account or tracking. Subscriptions and history are kept on this machine.|https://github.com/FreeTubeApp/FreeTube
Multimedia|Kdenlive (video editor)|kdenlive|kdenlive|x|!v6|KDE's multi-track video editor, bigger than OpenShot. Proxies, keyframes and colour grading for longer projects.|https://invent.kde.org/multimedia/kdenlive
Multimedia|Kodi (media centre)|kodi|kodi|x|!v6|A full-screen media centre for films, music, photos and TV. It is made to be driven from the sofa with a remote.|https://github.com/xbmc/xbmc
Multimedia|OBS Studio|obs-studio|obs|x|!v6|Records the screen and camera, or streams them live. Scenes and sources are mixed as it goes.|https://github.com/obsproject/obs-studio
Multimedia|OpenShot (video editor)|openshot@source|openshot-qt|x|64|A video editor to cut clips, lay them on tracks, and add titles, transitions and effects, then export for the web. Compiled here from GitHub: libopenshot-audio, libopenshot and openshot-qt.|https://github.com/OpenShot/openshot-qt
Multimedia|SimpleScreenRecorder (X11)|simplescreenrecorder|simplescreenrecorder|x|!v6,!v7,!a64|A screen recorder for the X desktop that is easy to set up and gentle on the CPU. Records X only, not Hyprland.|https://github.com/MaartenBaert/ssr
Multimedia|Sound Recorder|gnome-sound-recorder|gnome-sound-recorder|x|!v6|One button to record from the microphone. The recordings are listed below it, ready to play or share.|https://gitlab.gnome.org/GNOME/gnome-sound-recorder
Multimedia|YouTube Player (pipe-viewer)|pipe-viewer|pipe-viewer|t|*|Searches and plays YouTube from a terminal. Videos play in mpv, with no browser at all.|https://github.com/trizen/pipe-viewer
Programming|Arduino CLI|arduino-cli@testing|arduino-cli|h|*|Compiles and uploads Arduino sketches from a terminal. It also manages boards and libraries.|https://github.com/arduino/arduino-cli
Programming|GitHub CLI|github-cli|gh|h|*|GitHub from the command line: pull requests, issues and releases. gh pr create and gh repo clone, without the web page.|https://github.com/cli/cli
Programming|GNOME Builder|gnome-builder|gnome-builder|x|*|GNOME's IDE, for C, Rust, Python and Vala projects. Builds, runs and debugging are a click away.|https://gitlab.gnome.org/GNOME/gnome-builder
Programming|Node.js|nodejs npm|node|t|*|The JavaScript runtime outside the browser. npm comes with it to fetch packages.|https://github.com/nodejs/node
Programming|Thonny (Python IDE)|thonny|thonny|x|*|A Python editor for beginners. Step through code one line at a time and watch the variables change.|https://github.com/thonny/thonny
Science|Fraqtive (Mandelbrot fractals)|fraqtive@source|fraqtive|x|!v6|A fast generator of Mandelbrot-family fractals, with presets, colour gradients and high-resolution image export. Its 3D view needs desktop OpenGL, so on ARM boards it stays black; the 2D view is the program.|https://fraqtive.mimec.org/
Science|XaoS (fractal zoomer)|xaos@source|XaoS|x|!v6|A real-time fractal zoomer: fly smoothly into the Mandelbrot set and dozens of other fractals. Built-in tutorials explain the mathematics as you go.|https://xaos-project.github.io/
System|BleachBit (clean up disk space)|bleachbit@source|bleachbit|x|*|Frees disk space and privacy by deleting caches, logs, thumbnails and browser history. It works program by program, with a preview first.|https://github.com/bleachbit/bleachbit
System|btop++|btop|btop|t|*|A resource monitor in the terminal: CPU, memory, disks, network and processes. Everything is drawn as live graphs.|https://github.com/aristocratos/btop
System|Fastfetch|fastfetch|fastfetch|h|*|Prints the machine's logo and its specs in the terminal. OS, kernel, CPU, memory and desktop at a glance.|https://github.com/fastfetch-cli/fastfetch
System|Neofetch|neofetch@testing|neofetch|h|*|The original system-summary-with-a-logo script. Fastfetch is its faster successor.|https://github.com/dylanaraps/neofetch
System|Pika Backup|pika-backup@testing|pika-backup|x|*|Backs up your home folder with BorgBackup, to a USB disk or a server. It runs on a schedule and keeps only what changed.|https://gitlab.gnome.org/World/pika-backup
System|Syncthing GTK|syncthing-gtk@testing|syncthing-gtk|x|*|A window and tray icon for Syncthing. Syncthing keeps folders the same on several machines, with no cloud in between.|https://github.com/kozec/syncthing-gtk
System|System Monitoring Center|smc@source|system-monitoring-center|x|*|A task manager in the style of Windows'. CPU, memory, disks, network, sensors and processes on tabs, with graphs.|https://github.com/hakandundar34coding/system-monitoring-center
System|Timeshift|timeshift@testing|timeshift-launcher|x|*|Takes snapshots of the system files. A bad update can be rolled back to the last good one.|https://github.com/linuxmint/timeshift
Terminals|Microsoft PowerShell|powershell|pwsh|t|!v6,!x32|Microsoft's shell and scripting language, as on Windows. It passes objects between commands rather than text.|https://github.com/PowerShell/PowerShell
Tools|AntiMicroX (gamepad to keys)|antimicrox@testing|antimicrox|x|*|Maps a gamepad's buttons and sticks to keys and the mouse. Games and programs without controller support can be played with one.|https://github.com/AntiMicroX/antimicrox
Tools|ckb-next (Corsair keyboards)|ckb-next@testing|ckb-next|x|*|Lighting and macros for Corsair keyboards and mice. It replaces Corsair's own software, which does not run here.|https://github.com/ckb-next/ckb-next
Tools|FF Multi Converter|ffconverter@source|ffconverter|x|*|Converts audio, video, images and documents between formats, in batches. It is a front end to ffmpeg and ImageMagick.|https://github.com/l-koehler/FF-converter
Tools|Flameshot (screenshots)|flameshot|flameshot|x|!v6|Takes a screenshot and lets you mark it up. Draw arrows and boxes or blur a part before saving or copying.|https://github.com/flameshot-org/flameshot
Tools|GNOME Maps|gnome-maps|gnome-maps|x|!v6|OpenStreetMap maps with search and directions. It finds places by name and routes between them.|https://gitlab.gnome.org/GNOME/gnome-maps
Tools|KeePassXC (passwords)|keepassxc|keepassxc|x|*|A password manager kept in one encrypted file that you own. Its browser extension fills in logins.|https://github.com/keepassxreboot/keepassxc
Tools|Nautilus (GNOME Files)|nautilus|nautilus|x|*|GNOME's file manager. Browse, search and preview files, with network shares and removable disks alongside.|https://gitlab.gnome.org/GNOME/nautilus
Tools|Nemo (file manager)|nemo|nemo|x|*|Linux Mint's file manager. Two panes, a folder tree, and everything in the right-click menus.|https://github.com/linuxmint/nemo
Tools|Ollama (local AI models)|ollama|ollama|h|64|Downloads and runs large language models on this machine. ollama run llama3 starts a chat with no cloud service involved.|https://github.com/ollama/ollama
Tools|Organic Maps (offline maps)|organicmaps@testing|OMaps|x|*|Maps downloaded by region, for use with no connection. Hiking, cycling and car routes work offline too.|https://github.com/organicmaps/organicmaps
Tools|Raspberry Pi Imager|rpi-imager@testing|rpi-imager|x|!v6|Writes an operating system image to an SD card or USB stick. It can download the image for you first.|https://github.com/raspberrypi/rpi-imager
Tools|scrcpy (Android screen)|scrcpy|scrcpy|h|*|Shows an Android phone's screen in a window, over USB. Control it with this machine's keyboard and mouse.|https://github.com/Genymobile/scrcpy
Tools|Screenshot (GNOME)|gnome-screenshot|gnome-screenshot|x|*|Takes a screenshot of the screen, a window or an area. A delay can be set to catch a menu open.|https://gitlab.gnome.org/GNOME/gnome-screenshot
Tools|tldr (tealdeer)|tealdeer@testing|tldr|h|*|Short, example-first help pages for commands. tldr tar shows the five commands you actually wanted.|https://github.com/tealdeer-rs/tealdeer
Tools|VeraCrypt (encrypted volumes)|veracrypt@source|veracrypt|x|64|Makes an encrypted file or disk that opens as a drive with the right password. The successor to TrueCrypt; mounting asks for your admin password.|https://github.com/veracrypt/VeraCrypt
Transfer|Deluge (BitTorrent)|deluge|deluge|x|*|A BitTorrent client that grows with plug-ins. Scheduling, labels, blocklists and a web interface are all to hand.|https://github.com/deluge-torrent/deluge
Transfer|HTTrack (website copier)|httrack@testing|httrack|h|*|Downloads a whole website into a folder. It can then be browsed offline, links and all.|https://github.com/xroche/httrack
Transfer|OnionShare (share over Tor)|onionshare@testing|onionshare-cli|h|!v6|Shares files or a small website straight from this machine through Tor. No server and no account are needed.|https://github.com/onionshare/onionshare
Transfer|Persepolis (download manager)|persepolis@source|persepolis|x|!v6|A download manager built on aria2, using many connections per file. Queues, schedules, and video pages through yt-dlp.|https://github.com/persepolisdm/persepolis
STORETABLE
}
# <<< playbooks: table

# The architecture, in the catalogue's gate vocabulary.
store_arch() {
    case "$(apk --print-arch 2>/dev/null)" in
        aarch64) echo a64 ;; x86_64) echo x64 ;; armv7) echo v7 ;;
        armhf) echo v6 ;; x86) echo x32 ;; *) echo unknown ;;
    esac
}

# Every program this machine can have, one line each, both tables:
#   id|section|label|install|bin|mode|description|home|origin
# The store's rows are gated here exactly as catalogue_available gates the
# catalogue's; the catalogue file on disk is already gated.
rows() {
    # The catalogue's graphical programs have their two sentences and home
    # page in their playbooks; catalogue_abouts carries them here (A rows).
    { catalogue_abouts | sed 's/^/A|/'
      store_table | sed 's/^/S|/'
      [ -f "$CATFILE" ] && sed 's/^/C|/' "$CATFILE"
    } | awk -F'|' -v OFS='|' -v a="$(store_arch)" '
        $1 == "A" { about[$2] = $3; homes[$2] = $4; next }
        $1 == "S" {
            keep = 1; n = split($7, g, ",")
            for (i = 1; i <= n; i++) {
                if (g[i] == "*") continue
                if (g[i] == "64") { if (a != "a64" && a != "x64") keep = 0 }
                else if (substr(g[i], 1, 1) == "!" && a == substr(g[i], 2)) keep = 0
            }
            if (a == "unknown") keep = 1
            if (!keep) next
            sec = $2; label = $3; inst = $4; bin = $5; mode = $6; desc = $8; home = $9; o = "store"
        }
        $1 == "C" {
            if ($2 == "" || substr($2, 1, 1) == "#") next
            sec = $2; label = $3; inst = $4; bin = $5; mode = $6; desc = about[$5]; home = homes[$5]; o = "catalogue"
        }
        {
            id = bin
            if (id == "-") { split(inst, p, " "); id = p[1]; sub(/@.*/, "", id) }
            if (seen[id]++) next
            print id, sec, label, inst, bin, mode, desc, home, o
        }'
}

# rows() plus a status column in front: installed or -. One pass, with the
# apk database read once -- asking apk about 400 rows one at a time takes
# long enough to see.
#
# INSTALLED MEANS, by kind of row:
#   @source    the recipe's file list exists in $STATE -- this store put it there
#   @flathub   its command exists (the catalogue's contract)
#   apk names  every one of them is in apk's database. Not 'command -v': a
#              font has no command, and a package's command can be shadowed.
status_rows() {
    rows | awk -F'|' -v OFS='|' -v db="$APKDB" -v st="$STATE" -v path="$PATH" '
        BEGIN {
            while ((getline l < db) > 0) if (l ~ /^P:/) apk[substr(l, 3)] = 1
            np = split(path, pd, ":")
        }
        function command_exists(c,   i, f) {
            if (c == "-" || c == "") return 0
            for (i = 1; i <= np; i++) {
                f = pd[i] "/" c
                if ((getline _l < f) >= 0) { close(f); return 1 }
            }
            return 0
        }
        {
            n = split($4, pk, " "); ok = 1; src = ""
            for (i = 1; i <= n; i++) {
                p = pk[i]
                if (p ~ /@source$/) { src = substr(p, 1, length(p) - 7); continue }
                if (p ~ /@flathub$/) { if (!command_exists($5)) ok = 0; continue }
                sub(/@testing$/, "", p)
                if (!(p in apk)) ok = 0
            }
            if (src != "") { f = st "/" src ".files"; if ((getline _l < f) < 0) ok = 0; close(f) }
            print (ok ? "installed" : "-"), $0
        }'
}

row_for() {  # <id or label> -- the row, or nothing
    rows | awk -F'|' -v q="$1" '
        BEGIN { q = tolower(q) }
        tolower($1) == q || index(" " $4 " ", " " q "@source ") { print; found = 1; exit }
        { l = tolower($3); if (!first && index(l, q) == 1) first = $0 }
        END { if (!found && first) print first }'
}

# What a row's install field amounts to, in words.
how_installed() {  # <install field>
    for _p in $1; do
        case "$_p" in
            *@source)  printf 'compiled here from GitHub source (recipe %s)\n' "${_p%@source}" ;;
            *@testing) printf 'Alpine package %s, from edge/testing\n' "${_p%@testing}" ;;
            *@flathub) printf 'Flathub application %s\n' "${_p%@flathub}" ;;
            *)         printf 'Alpine package %s\n' "$_p" ;;
        esac
    done
}

# --------------------------------------------------------- the terminal ---
wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }
if wayland; then
    TERM_EMU="${TERMINAL:-$(have foot && echo foot || (have kitty && echo kitty) \
                          || (have alacritty && echo alacritty) || echo xterm)}"
else
    TERM_EMU="${TERMINAL:-$(have urxvt && echo urxvt || echo xterm)}"
fi

cmd_for() {  # <bin> <mode> -- kept identical to copal-menu's
    case "$2" in
        -) return 1 ;;
        t) printf '%s -e %s' "$TERM_EMU" "$1" ;;
        h) printf "%s -e sh -c '%s --help 2>&1 | head -40; echo; echo \"-- shell in this directory; Ctrl-D to close --\"; exec sh'" \
                  "$TERM_EMU" "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

# ----------------------------------------------------------------- privilege ---
# Root for apk and for /usr/local -- unless the prefix is somewhere this user
# can write and nothing needs apk, which is how the bench runs recipes.
need_root() {  # <args to re-run with>
    [ "$(id -u)" = 0 ] && return 0
    if [ "${COPAL_STORE_NODEPS:-0}" = 1 ] && mkdir -p "$PREFIX" "$STATE" 2>/dev/null \
       && [ -w "$PREFIX" ] && [ -w "$STATE" ]; then
        return 0
    fi
    have doas || die "needs root, and there is no doas here"
    exec doas "$0" "$@"
}

# ------------------------------------------------------------- apk rows ---
enable_testing_tag() {
    grep -q '^@testing[[:space:]]' /etc/apk/repositories 2>/dev/null && return 0
    _m=$(sed -n 's|^\(https\?://.*\)/v[0-9][0-9.]*/main[[:space:]]*$|\1|p' \
             /etc/apk/repositories 2>/dev/null | head -n1)
    [ -n "$_m" ] || _m="https://dl-cdn.alpinelinux.org/alpine"
    note "adding $_m/edge/testing as @testing -- used ONLY for names written name@testing"
    printf '@testing %s/edge/testing\n' "$_m" >> /etc/apk/repositories
    apk update >/dev/null 2>&1 || true
}

apk_install() {  # <names...>
    case " $* " in *@testing*) enable_testing_tag ;; esac
    # shellcheck disable=SC2068
    apk add "$@"
}

# THE OPTIONALS. Alpine has no "recommends": a program arrives without the
# plugins, codecs, helpers and data that make it whole -- abcde with no
# encoder rips and stops, links has no graphical mode, ranger previews
# nothing, zathura opens no PDF. This table names them, per package: a word
# is a package, a word with * is a family resolved from the index at install
# time (claws-mail-plugins-*). Installed with the program, quietly, and never
# a reason for its install to fail; 'copal-store optionals --installed'
# catches up everything already on the machine (stage 18 runs it). The last
# rows are keyed on shared libraries rather than programs: every GTK viewer
# reads images through gdk-pixbuf, every Qt one through its image plugins, so
# one row there gives GIMP's neighbours, gThumb, Gwenview and the rest WebP,
# AVIF, HEIF, JPEG XL and camera RAW at once.
#
# LEFT OUT ON PURPOSE: server modules (php83-*, samba-dc and winbind,
# headless daemons such as qbittorrent-nox and vlc-daemon) -- each one widens
# what a server exposes, and is a decision, not an extra; -systemd files
# (this is OpenRC); firewall rule files (-nftrules); whole language library
# ecosystems (perl-*, ruby-*, lua5.4-*, go-*, cargo-*); Vim plugins, which
# would change the editor Copal configures; and giant data (KiCad's 3D
# models, every Tesseract language). The security tools are left as they are.
optionals_table() {
    cat <<'OPTIONALS'
abcde|lame opus-tools vorbis-tools flac
abiword|abiword-plugin-*
alacritty|alacritty-graphics
aspell|aspell-en
audacious|audacious-plugins
claws-mail|claws-mail-plugins-*
clang22|clang22-analyzer
cmake|cmake-extras
cppcheck|cppcheck-gui cppcheck-htmlreport
fortune|fortune-alpine-tips
gdb|gdb-dashboard gdb-multiarch
geany|geany-plugins
gedit|gedit-plugins
gimp|gimp-plugin-gmic
graphviz|graphviz-graphs
gthumb|gthumb-extra-formats gthumb-raw-files gthumb-map-view gthumb-webalbums
hackrf|hackrf-firmware
helix|helix-tree-sitter-vendor
hunspell|hunspell-en hunspell-en-gb
inkscape|inkscape-tutorials
irssi|irssi-otr irssi-perl irssi-xmpp
krita|krita-kseexpr
links|links-graphics
mdbook|mdbook-admonish mdbook-katex mdbook-linkcheck mdbook-mermaid mdbook-plantuml
meson|meson-tools
micro|micro-tetris
mpd|mpd-mpris
mpv|mpv-mpris
mupdf|mupdf-tools
mypaint|mypaint-brushes
nano|nano-syntax
nnn|nnn-plugins mediainfo atool
py3-matplotlib|py3-matplotlib-gtk3 py3-matplotlib-tk
python3|python3-tkinter python3-idle
py3-lsp-server|py3-pyflakes py3-pycodestyle
qpdf|qpdf-fix-qdf
scrcpy|android-udev-rules
qemu-system-x86_64|qemu-img
redshift|gammastep hyprsunset
ranger|highlight mediainfo atool ffmpegthumbnailer poppler-utils w3m-image
screen|screen-message
squashfs-tools|squashfs-tools-ng
strace|strace-tui
tesseract-ocr|tesseract-ocr-data-eng tesseract-ocr-data-osd
thunar|thunar-archive-plugin thunar-media-tags-plugin thunar-gtkhash-plugin thunar-vcs-plugin-git thunar-volman
tmux|tmux-resurrect
valgrind|valgrind-scripts
vim|vim-tutor
w3m|w3m-image
weechat|weechat-lua weechat-perl weechat-python weechat-spell weechat-matrix
xfe|xfe-xfa xfe-xfi xfe-xfp xfe-xfw
xscreensaver|xscreensaver-extras xscreensaver-gl-extras
zathura|zathura-cb zathura-djvu zathura-ps
gstreamer|gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
gdk-pixbuf|glycin-loaders-all libopenraw-pixbuf-loader
qt6-qtbase|qt6-qtimageformats kimageformats
imagemagick|imagemagick-jxl imagemagick-webp
libheif|libheif-plugins-all
vips|vips-heif vips-jxl
OPTIONALS
}

# The optionals of these packages that the index has and this machine lacks.
optionals_of() {  # <apk names...>
    _want=""
    for _p in "$@"; do
        _p=${_p%@*}
        _l=$(optionals_table | awk -F'|' -v p="$_p" '$1 == p { print $2 }')
        for _o in $_l; do
            case "$_o" in
                *\**) _want="$_want $(apk search -q "$_o" 2>/dev/null | grep -Ev -- '-(dev|dbg|doc|lang|static|systemd|nftrules|pyc)$')" ;;
                *)    _want="$_want $_o" ;;
            esac
        done
    done
    [ -n "$_want" ] || return 0
    # shellcheck disable=SC2086
    _have=$(apk info -e $_want 2>/dev/null)
    # shellcheck disable=SC2086
    _want=$(printf '%s\n' $_want | sort -u | grep -vxF "$(printf '%s\n' $_have)")
    [ -n "$_want" ] || return 0
    # One query for all of them: the names the index has, NAME-VER-rN cut
    # back to NAME. (One query each took a minute for a hundred names.)
    # shellcheck disable=SC2086
    _want=$(apk search -e $_want 2>/dev/null | sed 's/-[^-]*-r[0-9]*$//' | sort -u)
    [ -n "$_want" ] || return 0
    # A name only edge/testing carries is asked for as NAME@testing, as the
    # man pages are: one untagged testing name makes apk refuse the batch.
    # shellcheck disable=SC2086
    apk policy $_want 2>/dev/null | awk '
        / policy:$/ { if (n != "") print n (u ? "" : "@testing"); n = $1; sub(/:$/, "", n); u = 0; next }
        /^    / && $1 !~ /^@/ { u = 1 }
        END { if (n != "") print n (u ? "" : "@testing") }'
}

# Install them: one transaction, and one by one if that fails, so a single
# missing or testing-only name costs only itself. Never a failure.
optionals_for() {  # <apk names...>
    _o=$(optionals_of "$@")
    [ -n "$_o" ] || return 0
    case " $(echo $_o) " in *@testing*) enable_testing_tag ;; esac
    # shellcheck disable=SC2086
    if apk add -q $_o >/dev/null 2>&1; then
        _got=$(echo $_o)
    else
        _got=""
        for _n in $_o; do
            apk add -q "$_n" >/dev/null 2>&1 && _got="$_got $_n"
        done
    fi
    [ -n "$_got" ] || return 0
    note "optionals: $_got"
    # The summary keeps it: what was added, for which packages.
    { printf '\n== optionals  %s  for %s\n' "$(date '+%Y-%m-%d %H:%M')" "$(echo "$@")"
      echo $_got | fold -s -w 64 | sed '1s/^/   added      /; 2,$s/^/              /'
    } >> "$LOGDIR/summary.txt" 2>/dev/null
    return 0
}

# Every installed package's optionals: what stage 18 runs once the programs
# are in, and a way to catch up a machine installed before this table.
optionals_installed() {
    _keys=$(optionals_table | cut -d'|' -f1)
    # shellcheck disable=SC2086
    _inst=$(apk info -e $_keys 2>/dev/null)
    [ -n "$_inst" ] || { note "nothing installed has optionals"; return 0; }
    # shellcheck disable=SC2086
    optionals_for $_inst
}

# ACCESS. Some programs install fine and then cannot reach what they are
# for, because Alpine gives the device or the shared files to a group the
# account is not in: an SDR dongle or an Android phone (plugdev), packet capture (wireshark),
# ZAngband's and the BSD games' score files (users), a CD burner (cdrom), a
# serial radio or instrument (dialout). This table says which installed
# command wants which group; 'copal-store access' adds the account to each
# and applies the two file fixes that go with them. Stage 12 does the same
# for a fresh install; this is for everything installed since -- Copal Apps
# and the menu's Install run it after every install -- and for machines
# installed before these lines.
access_table() {
    cat <<'ACCESS'
rtl_test|plugdev
hackrf_info|plugdev
scrcpy|plugdev
adb|plugdev
dumpcap|wireshark
zangband|users
robots|users
cdparanoia|cdrom
cdrdao|cdrom
xorriso|cdrom
cdw|cdrom
rigctl|dialout
direwolf|dialout
radbeeper|dialout
arduino-cli|dialout
ACCESS
}

# The account to give access to: the one that asked through doas or sudo,
# else the administrator -- the first member of wheel who is not root (a
# boot-time queue has no one who asked).
store_user() {
    _su="${DOAS_USER:-${SUDO_USER:-}}"
    [ -n "$_su" ] || _su=$(getent group wheel | cut -d: -f4 | tr ',' '\n' | grep -vx root | head -n 1)
    [ -n "$_su" ] && [ "$_su" != root ] && echo "$_su"
}

access_fix() {  # [user]
    _u=${1:-$(store_user)}
    [ -n "$_u" ] && id "$_u" >/dev/null 2>&1 || { note "no account to give access to"; return 0; }
    _added=""
    for _g in $(access_table | while IFS='|' read -r _c _grp; do
                    command -v "$_c" >/dev/null 2>&1 && echo "$_grp"; done | sort -u); do
        getent group "$_g" >/dev/null 2>&1 || continue
        id -nG "$_u" | tr ' ' '\n' | grep -qx "$_g" && continue
        adduser "$_u" "$_g" >/dev/null 2>&1 && _added="$_added $_g"
    done
    [ -z "$_added" ] || note "$_u added to:$_added -- log out and in for it to take effect"
    # The BSD games look for their scores where the package does not put them.
    if command -v robots >/dev/null 2>&1 && [ -d /usr/share/bsdgames ] && [ ! -e /var/lib/bsdgames ]; then
        ln -s /usr/share/bsdgames /var/lib/bsdgames && note "/var/lib/bsdgames -> /usr/share/bsdgames"
    fi
    # An RTL2832U is a radio here, not a TV tuner: keep the DVB-T driver off it.
    if command -v rtl_test >/dev/null 2>&1 && [ ! -e /etc/modprobe.d/copal-rtl-sdr.conf ]; then
        printf '%s\n' '# Written by Copal: an RTL2832U is used as a radio, not a TV tuner.' \
            'blacklist dvb_usb_rtl28xxu' 'blacklist rtl2832' 'blacklist rtl2830' 'blacklist rtl2832_sdr' \
            > /etc/modprobe.d/copal-rtl-sdr.conf && note "/etc/modprobe.d/copal-rtl-sdr.conf written"
    fi
    return 0
}

# A terminal program's man page comes with it: its package's -doc, when the
# index has one, is not installed yet, and is under the installer's cap
# (MAN_DOC_CAP_KB in copal-prep.sh, where install_manuals says why). Quiet,
# and never a reason to fail the install.
man_pages_for() {  # <apk names...>
    # The -doc of each package's origin (openssh-client -> openssh-doc).
    _md=$(apk query --fields origin $(for _p in "$@"; do echo "${_p%@*}"; done) 2>/dev/null \
          | sed -n 's/^Origin: \(.*\)/\1-doc/p' | sort -u)
    _mh=$(apk info -e $_md 2>/dev/null)
    _md=$(printf '%s\n' $_md | grep -vxF "$(printf '%s\n' $_mh)" || true)
    [ -n "$_md" ] || return 0
    _md=$(apk search -e $_md 2>/dev/null | sed 's/-[^-]*-r[0-9]*$//' | sort -u)
    [ -n "$_md" ] || return 0
    _mbig=$(apk info -s $_md 2>/dev/null | awk '
        / installed size:$/ { n = $1; sub(/-[^-]*-r[0-9]*$/, "", n); next }
        n != "" && NF == 2 {
            k = $1; u = $2
            if (u == "MiB") k *= 1024; else if (u == "GiB") k *= 1048576; else if (u == "B") k /= 1024
            if (k > 32768) print n
            n = "" }')
    _md=$(printf '%s\n' $_md | grep -vxF "$(printf '%s\n' $_mbig)" || true)
    [ -n "$_md" ] || return 0
    # A -doc that only edge/testing has is masked unless it is asked for by
    # its tagged name: one untagged name among many fails the whole apk
    # transaction (seen on the bench: sigrok-cli-doc, xmp-doc and six more
    # took the other 144 down with them -- install_manuals in copal-prep.sh). apk policy says, per package,
    # whether any repository without a tag carries it.
    _md=$(apk policy $_md 2>/dev/null | awk '
        / policy:$/ { if (n != "") print n (u ? "" : "@testing"); n = $1; u = 0; next }
        /^    / && $1 !~ /^@/ { u = 1 }
        END { if (n != "") print n (u ? "" : "@testing") }')
    apk add -q $_md >/dev/null 2>&1 && note "man page: $(echo $_md)"
    # Under the lock mandoc-apropos's trigger takes: it rebuilds in the
    # background, and two unlocked writers corrupt mandoc.db.
    have makewhatis && { ( flock 9 && makewhatis -T utf8 ) 9>/tmp/makewhatis.lock >/dev/null 2>&1 || true; }
}

# ------------------------------------------------------------ recipes: kit ---
#
# A recipe is a playbook that builds from source (playbooks/, and
# docs/playbooks-plan.md). Its header gives the lists, made into functions here:
#
#   NAME_bdeps   'build:' -- apk packages needed only to build (removed afterwards)
#   NAME_rdeps   'runs:'  -- apk packages needed to run (kept, under a virtual
#                            package, until 'remove')
#
# and its body the steps, each optional but install:
#
#   NAME_pre     prerequisites and preconfiguration, as root, before the build
#   NAME_install download, patch, compile, and install into $DEST$PREFIX
#   NAME_post    postconfiguration: first-run settings for each home, never
#                overwriting, and anything else the program needs to be whole
#
# The build runs in $W, a fresh directory, and installs into the staging tree
# $DEST. Only when it has all succeeded is the staging tree copied onto the
# system and its file list kept in $STATE/NAME.files -- so a failed build
# leaves nothing behind but its log, and 'remove' knows every file to take.

# A tagged release's source from GitHub, verified. Prints the unpacked directory.
# A 40-digit commit in place of the tag, for a project whose last tag is years
# behind its working tree.
gh_source() {  # <owner/repo> <tag or commit> <sha256>
    _repo=${1#*/}; _f="$CACHE/$_repo-$2.tar.gz"
    case "$2" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) _ref="$2" ;;
        *) _ref="refs/tags/$2" ;;
    esac
    mkdir -p "$CACHE"
    if [ ! -s "$_f" ]; then
        note "downloading $1 $2" >&2
        curl -fL --retry 3 -o "$_f.part" "https://github.com/$1/archive/$_ref.tar.gz" >&2 \
            && mv "$_f.part" "$_f" || { rm -f "$_f.part"; warn "could not download $1 $2"; return 1; }
    fi
    verify_sum "$_f" "$3" || return 1
    printf '%s\n' "$_f" >> "$W/.sources" 2>/dev/null || true
    _d="$W/src-$_repo"; rm -rf "$_d"; mkdir -p "$_d"
    tar -xzf "$_f" -C "$_d" || { warn "$_f did not unpack"; return 1; }
    printf '%s\n' "$_d"/*
}

# One release file from GitHub, verified. Prints its path.
gh_asset() {  # <owner/repo> <tag> <file> <sha256>
    _f="$CACHE/${1#*/}-$2-$3"
    mkdir -p "$CACHE"
    if [ ! -s "$_f" ]; then
        note "downloading $1 $2 $3" >&2
        curl -fL --retry 3 -o "$_f.part" "https://github.com/$1/releases/download/$2/$3" >&2 \
            && mv "$_f.part" "$_f" || { rm -f "$_f.part"; warn "could not download $3"; return 1; }
    fi
    verify_sum "$_f" "$4" || return 1
    printf '%s\n' "$_f" >> "$W/.sources" 2>/dev/null || true
    printf '%s\n' "$_f"
}

# One file from a project's own site, verified -- for the rare project whose
# GitHub archive cannot be built (Ardour's is a README saying so). Cached
# under its own name.
url_asset() {  # <url> <sha256>
    _f="$CACHE/${1##*/}"
    mkdir -p "$CACHE"
    if [ ! -s "$_f" ]; then
        note "downloading $1" >&2
        curl -fL --retry 3 -o "$_f.part" "$1" >&2 \
            && mv "$_f.part" "$_f" || { rm -f "$_f.part"; warn "could not download $1"; return 1; }
    fi
    verify_sum "$_f" "$2" || return 1
    printf '%s\n' "$_f" >> "$W/.sources" 2>/dev/null || true
    printf '%s\n' "$_f"
}

verify_sum() {  # <file> <sha256>
    printf '%s  %s\n' "$2" "$1" | sha256sum -c - >/dev/null 2>&1 && return 0
    warn "checksum mismatch on $1 -- deleted, not built"
    rm -f "$1"; return 1
}

# Configure, build and stage a CMake project. Extra arguments go to cmake.
# CMAKE_POLICY_VERSION_MINIMUM: CMake 4 refuses a project that declares a
# minimum below 3.5, which older releases do; this is CMake's own remedy.
# -D_LARGEFILE64_SOURCE: musl 1.2.4 declares fopen64, stat64 and the other
# LFS64 names only when asked, and code written on glibc calls them freely.
# Through CMAKE_*_FLAGS rather than an exported CFLAGS, which would also
# reach autotools and quietly replace its default -O2.
# -z stack-size: a thread gets 128 KB of stack on musl and 8 MB on glibc,
# and code written on glibc assumes the 8. musl takes its default from this
# field of the program header, so every thread the program starts gets
# glibc's size. It reserves address space, not memory. DDNet's renderer
# thread overflowed without it, on the first store into its stack frame.
cmake_stage() {  # <source dir> [cmake args...]
    _s="$1"; shift
    _b="$W/build-$(basename "$_s")"
    cmake -S "$_s" -B "$_b" -G Ninja -Wno-dev \
          -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DCMAKE_PREFIX_PATH="$DEST$PREFIX;$PREFIX" \
          -DCMAKE_INSTALL_RPATH="$PREFIX/lib" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
          -DCMAKE_C_FLAGS="${CFLAGS:-} -D_LARGEFILE64_SOURCE" \
          -DCMAKE_CXX_FLAGS="${CXXFLAGS:-} -D_LARGEFILE64_SOURCE" \
          -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS:-} -Wl,-z,stack-size=8388608" "$@" \
      && nice -n 10 ninja -C "$_b" -j "$JOBS" \
      && DESTDIR="$DEST" ninja -C "$_b" install
}

# A launcher script under $PREFIX/bin.
launcher() {  # <name> -- the script body on stdin
    mkdir -p "$DEST$PREFIX/bin"
    { printf '#!/bin/sh\n# written by copal-store\n'; cat; } > "$DEST$PREFIX/bin/$1"
    chmod 0755 "$DEST$PREFIX/bin/$1"
}

# A menu entry, for launchers that read .desktop files (wofi, rofi, GNOME).
desktop_entry() {  # <id> <Name> <Exec> <Icon> <Categories> <Comment>
    mkdir -p "$DEST$PREFIX/share/applications"
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nCategories=%s\nComment=%s\nTerminal=false\n' \
        "$2" "$3" "$4" "$5" "$6" > "$DEST$PREFIX/share/applications/$1.desktop"
}

# Write FILE into every real home on the machine -- root's and the users' --
# only where it is absent, so a person's own settings are never touched.
seed_homes() {  # <relative path> -- contents on stdin
    _t="$W/seed.$$"; cat > "$_t"
    for _h in /root /home/*; do
        [ -d "$_h" ] && [ -w "$_h" ] || continue
        [ -e "$_h/$1" ] && continue
        mkdir -p "$_h/$(dirname "$1")" && cp "$_t" "$_h/$1" || continue
        _own=$(stat -c '%u:%g' "$_h" 2>/dev/null) \
            && chown -R "$_own" "$_h/${1%%/*}" 2>/dev/null || true
    done
    rm -f "$_t"
}

apply_patch() {  # <dir> <patch function>
    note "patch: $2"
    "$2" | (cd "$1" && patch -p1 --no-backup-if-mismatch -s) \
        || { warn "$2 did not apply"; return 1; }
}

# ------------------------------------------------------------ recipes ---
#
# The recipes live in playbooks/<shelf>/<project>.sh, one file per project,
# and are copied in here by 'make sync-playbooks' (tools/copal-playbooks.py),
# with NAME_bdeps, NAME_rdeps, NAME_needs and NAME_source made from each
# playbook's header. docs/playbooks-plan.md is the format.
# >>> playbooks: recipes -- generated from playbooks/ by 'make sync-playbooks'; edit those, not this

# ---- playbooks/Games/alephone.sh
# Marathon: Bungie's trilogy, released free, on Aleph One, the engine built
# from Bungie's own source. The release tarball has its configure script
# already generated; the three games' data come from the same GitHub release
# (about 90 MB between them) and each gets its own launcher.
ALEPHONE_VER=20250829
# libvpx, libyuv, libebml and libmatroska: film export (recording a game
# or a replay to video) and video playback; miniupnpc: hosting a network
# game through a home router. All five were absent from the first build.
# Film export blits with glBlitFramebufferEXT, a name Alpine's libGL
# (glvnd) does not export; the core glBlitFramebuffer it does export has
# the same signature, so the one is defined as the other.
alephone_install() {
    _t=$(gh_asset Aleph-One-Marathon/alephone "release-$ALEPHONE_VER" "AlephOne-$ALEPHONE_VER.tar.bz2" \
         e7c447034aa35dd85ca6836dd8367034c4f4512aa0d14e9781d7033946098806) || return 1
    mkdir -p "$W/src" && tar -xjf "$_t" -C "$W/src"
    _s=$(printf '%s\n' "$W"/src/*)
    (cd "$_s" && ./configure --prefix="$PREFIX" CXXFLAGS="-g -O2 -DglBlitFramebufferEXT=glBlitFramebuffer" \
        && nice -n 10 make -j "$JOBS" && make DESTDIR="$DEST" install)
    _data="$PREFIX/share/alephone"
    mkdir -p "$DEST$_data"
    for _g in "Marathon:644fa202a8df19fd5c36b8c4bc3777c33afd291e2874669defc1819d8e132620:marathon:Marathon" \
              "Marathon2:cac0ce7bd37b91f5da15ad63be1b6131e1f75496906e8fd6af20f0bb1ab86cf9:marathon2:Marathon 2" \
              "MarathonInfinity:8b6ba6b2ca9714a2235b3063281f176ccd27a2e23b96c014f5c700d9a222a018:marathon-infinity:Marathon Infinity"; do
        _z=${_g%%:*}; _x=${_g#*:}; _sum=${_x%%:*}; _x=${_x#*:}; _cmd=${_x%%:*}; _dir=${_x#*:}
        _f=$(gh_asset Aleph-One-Marathon/alephone "release-$ALEPHONE_VER" "$_z-$ALEPHONE_VER-Data.zip" "$_sum")
        unzip -q "$_f" -d "$DEST$_data"
        launcher "$_cmd" <<EOF
exec "$PREFIX/bin/alephone" "$_data/$_dir" "\$@"
EOF
        desktop_entry "$_cmd" "$_dir" "$_cmd" alephone "Game;ActionGame;" "Bungie's $_dir, on the Aleph One engine"
    done
}
alephone_bdeps() { echo "build-base boost-dev asio-dev sdl2-dev sdl2_ttf-dev sdl2_image-dev openal-soft-dev libsndfile-dev glu-dev mesa-dev zlib-dev libpng-dev curl-dev zziplib-dev libvorbis-dev libvpx-dev libyuv-dev libebml-dev libmatroska-dev miniupnpc-dev"; }
alephone_rdeps() { echo ""; }
alephone_needs() { echo ""; }
alephone_source() { echo "github Aleph-One-Marathon/alephone"; }

# ---- playbooks/Games/amiberry.sh
# Amiberry: an Amiga emulator tuned for ARM, on SDL3. Alpine has every library
# it asks for, two of them in edge/testing, so none of its FetchContent
# fallbacks (which would clone at build time) is used. It needs Kickstart ROMs
# to run most software; its built-in AROS ROM boots without them.
AMIBERRY_VER=8.3.0
amiberry_install() {
    _s=$(gh_source BlitterStudio/amiberry "v$AMIBERRY_VER" \
         881628c2465fe28063b8444350e78167e7a9ed047def66b9ef3cfdabd4bdc1d6) || return 1
    # musl declares aarch64's mcontext_t.regs as unsigned long, glibc as
    # unsigned long long: both 64 bits there, so the cast is exact.
    sed -i 's|unsigned long long\* regs = context->regs;|unsigned long long* regs = reinterpret_cast<unsigned long long*>(context->regs);  // copal: musl|' \
        "$_s/src/osdep/sigsegv_handler.cpp"
    # musl's C++ NULL is nullptr, which no static_cast turns into an address;
    # glibc's is an integer. The intent is zero.
    sed -i 's|static_cast<uaecptr>(NULL)|static_cast<uaecptr>(0)|g' "$_s/src/custom.cpp"
    # Native file dialogs: nativefiledialog-extended is a git submodule, which
    # GitHub's archive leaves as an empty directory, so the build turned them
    # off. Release 1.4.0 fills it -- the first with the Wayland window API
    # (NFD_SetWaylandDisplay) Amiberry calls; 1.2.1, which Naev pins, lacks
    # it. Amiberry builds it for xdg-desktop-portal, which needs only D-Bus.
    _n=$(gh_source btzy/nativefiledialog-extended v1.4.0 \
         38116050495cd7de77a91d6d8d59c1aa0a0848c56daa60029bd5b59f3c897229) || return 1
    rmdir "$_s/external/nativefiledialog-extended" && cp -r "$_n" "$_s/external/nativefiledialog-extended"
    # ...which has a submodule of its own, the Wayland protocol files, left
    # empty the same way. Alpine's wayland-protocols is that repository.
    _wp=$(pkg-config --variable=pkgdatadir wayland-protocols)
    rm -rf "$_s/external/nativefiledialog-extended/3ps/wayland-protocols"
    ln -s "$_wp" "$_s/external/nativefiledialog-extended/3ps/wayland-protocols"
    cmake_stage "$_s" -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DUSE_DBUS=OFF -DUSE_GPIOD=OFF
}
amiberry_bdeps() { echo "build-base cmake samurai pkgconf sdl3-dev sdl3_image-dev@testing flac-dev mpg123-dev libpng-dev zlib-dev curl-dev nlohmann-json libpcap-dev zstd-dev libmpeg2-dev portmidi-dev enet-dev libserialport-dev@testing mesa-dev dbus-dev wayland-dev wayland-protocols"; }
amiberry_rdeps() { echo "sdl3 sdl3_image@testing flac-libs mpg123-libs libpng libcurl libpcap zstd-libs libmpeg2 portmidi enet libserialport@testing"; }
amiberry_needs() { echo ""; }
amiberry_source() { echo "github BlitterStudio/amiberry"; }

# ---- playbooks/Audio/ardour.sh
# Ardour: the digital audio workstation, built with waf. Its GitHub archives
# hold only a README: the build takes its version from 'git describe' or from
# libs/ardour/revision.cc, which only ardour.org's own source tarball has --
# so that tarball is the source here, pinned by SHA-256 like the rest.
#
# Backends: ALSA, PulseAudio (which PipeWire answers) and the dummy one. JACK
# is left out, so installing Ardour does not bring a JACK server with it;
# PipeWire's JACK layer is there for anyone who wants it. No phone-home
# check for updates, and no LRDF (LADSPA metadata nobody ships any more).
# Ardour is written against the glibmm-2.4 API series, which Alpine packages
# as glibmm2.66, cairomm1.14 and pangomm2.46; glibmm-dev is the newer 2.68.
#
# Its bundled GTK 2 (libs/tk/ytk and ydk) ships a fixed config.h that
# declares HAVE_GNU_FTW, glibc's nftw() extension -- FTW_ACTIONRETVAL and
# the FTW_STOP / FTW_SKIP_SUBTREE / FTW_CONTINUE returns, which musl does not
# have. With the two lines gone GTK takes its own portable path, a plain
# nftw walk, which is what it does on every non-glibc system.
ARDOUR_VER=9.8.0
ardour_install() {
    _t=$(url_asset "https://community.ardour.org/src/Ardour-$ARDOUR_VER.tar.bz2" \
         1f1a0ae658fb3b10e3fa6f9cab952ab6500955594c3773c5e9421f5e42b23d59) || return 1
    tar -xjf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/Ardour-$ARDOUR_VER"
    sed -i '/#define HAVE_GNU_FTW 1/d' "$_s/libs/tk/ytk/config.h" "$_s/libs/tk/ydk/config.h"
    _a=""; [ "$(uname -m)" = aarch64 ] && _a="--arm64"
    (cd "$_s" && LINKFLAGS="-Wl,-z,stack-size=8388608" python3 ./waf configure --prefix="$PREFIX" \
            --optimize --with-backends=alsa,pulseaudio,dummy --no-phone-home --no-lrdf \
            --freedesktop $_a \
        && nice -n 10 python3 ./waf build -j "$JOBS" \
        && python3 ./waf install --destdir="$DEST") || return 1
}
ardour_bdeps() { echo "build-base python3 pkgconf gettext-dev itstool boost-dev glibmm2.66-dev libsndfile-dev libsamplerate-dev liblo-dev taglib-dev vamp-sdk-dev rubberband-dev aubio-dev lv2-dev lilv-dev serd-dev sord-dev sratom-dev suil-dev fftw-dev libarchive-dev curl-dev libusb-dev cairomm1.14-dev pangomm2.46-dev pango-dev alsa-lib-dev pulseaudio-dev libxml2-dev libwebsockets-dev readline-dev libxrandr-dev libxinerama-dev"; }
ardour_rdeps() { echo ""; }
ardour_needs() { echo ""; }
ardour_source() { echo "url community.ardour.org"; }

# ---- playbooks/Games/astromenace.sh
# AstroMenace: a 3D shoot-'em-up, CMake over SDL2, OpenAL and ALUT. The build
# packs the raw game data into gamedata.vfs by running the binary it just
# made (--pack), and the game looks for that file in DATADIR.
ASTROMENACE_VER=1.4.3
astromenace_install() {
    _s=$(gh_source viewizard/astromenace "v$ASTROMENACE_VER" \
         c16b56bfa91f0b1ac1520d09ead2a1fbb536cbd3d4f3a792a222d44bc708eab1) || return 1
    _d="$PREFIX/lib/copal-store/astromenace"
    cmake -S "$_s" -B "$W/build" -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$_d" -DDATADIR="$_d" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    nice -n 10 ninja -C "$W/build" -j "$JOBS"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$W/build/astromenace" "$W/build/gamedata.vfs" "$DEST$_d/"
    cp "$_s/share/astromenace_128.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/astromenace.png"
    launcher astromenace <<EOF
exec "$_d/astromenace" "\$@"
EOF
    desktop_entry astromenace AstroMenace astromenace astromenace "Game;ActionGame;" \
        "3D space shoot-'em-up"
}
astromenace_bdeps() { echo "build-base cmake samurai sdl2-dev openal-soft-dev freealut-dev@testing libogg-dev libvorbis-dev freetype-dev fontconfig-dev mesa-dev"; }
astromenace_rdeps() { echo "sdl2 openal-soft-libs freealut@testing libvorbis freetype fontconfig"; }
astromenace_needs() { echo ""; }
astromenace_source() { echo "github viewizard/astromenace"; }

# ---- playbooks/System/bleachbit.sh
# BleachBit's own Makefile installs it, prefix and DESTDIR both honoured.
BLEACHBIT_VER=6.0.4
bleachbit_install() {
    _s=$(gh_source bleachbit/bleachbit "v$BLEACHBIT_VER" \
         5af7cec3ed77b38e2e9ef91201e69d75100664116669b04a053dfd788d996f12) || return 1
    make -C "$_s" install prefix="$PREFIX" DESTDIR="$DEST"
    # po/Makefile writes the translations to /usr/share/locale whatever the
    # prefix; they belong beside everything else.
    mkdir -p "$DEST$PREFIX/share"
    mv "$DEST/usr/share/locale" "$DEST$PREFIX/share/locale"
    rmdir -p "$DEST/usr/share" 2>/dev/null || true
    # The script looks for its package only in /usr/share; it is kept
    # beside the rest and started with the prefix on the path.
    mkdir -p "$DEST$PREFIX/lib/copal-store/bleachbit"
    mv "$DEST$PREFIX/bin/bleachbit" "$DEST$PREFIX/lib/copal-store/bleachbit/bleachbit"
    launcher bleachbit <<EOF
export PYTHONPATH="$PREFIX/share\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$PREFIX/lib/copal-store/bleachbit/bleachbit" "\$@"
EOF
}
# The first start writes its settings file and reports a write error while
# doing it (seen on the bench, with a fresh home); a settings file already
# there, marked as past the first start, and the window opens clean.
bleachbit_post() {
    seed_homes .config/bleachbit/bleachbit.ini <<'EOF'
[bleachbit]
first_start = False
EOF
}
bleachbit_bdeps() { echo "make"; }
bleachbit_rdeps() { echo "python3 py3-gobject3 gtk+3.0"; }
bleachbit_needs() { echo ""; }
bleachbit_source() { echo "github bleachbit/bleachbit"; }

# ---- playbooks/Browsers/browsh.sh
# Browsh: the web in a terminal, rendered by a real Firefox running headless
# and drawn as text and half-block colour. The Go program embeds its Firefox
# extension (go:embed browsh.xpi); the release publishes that extension and,
# since 1.8.3, no Linux binary -- so the extension is fetched from the same
# release and built in. It drives whichever Firefox is here; Copal's is ESR.
BROWSH_VER=1.8.3
browsh_install() {
    _s=$(gh_source browsh-org/browsh "v$BROWSH_VER" \
         88462530dbfac4e17c8f8ba560802d21042d90236043e11461a1cfbf458380ca) || return 1
    _x=$(gh_asset browsh-org/browsh "v$BROWSH_VER" "browsh-$BROWSH_VER.xpi" \
         c0b72d7c61c30a0cb79cc1bf9dcf3cdaa3631ce029f1578e65c116243ed04e16) || return 1
    cp "$_x" "$_s/interfacer/src/browsh/browsh.xpi"
    mkdir -p "$DEST$PREFIX/lib/copal-store/browsh"
    (cd "$_s/interfacer" && GOPATH="$W/go" GOCACHE="$W/gocache" GOFLAGS=-modcacherw CGO_ENABLED=0 \
        go build -trimpath -ldflags "-s -w" -o "$DEST$PREFIX/lib/copal-store/browsh/browsh" ./cmd/browsh)
    launcher browsh <<EOF
_ff=\$(command -v firefox || command -v firefox-esr)
exec "$PREFIX/lib/copal-store/browsh/browsh" --firefox.path "\$_ff" "\$@"
EOF
}
browsh_bdeps() { echo "go"; }
browsh_rdeps() { echo "firefox-esr"; }
browsh_needs() { echo ""; }
browsh_source() { echo "github browsh-org/browsh"; }

# ---- playbooks/Games/ccleste.sh
# Celeste Classic, the PICO-8 original of Celeste, in lemon32767's C port:
# the cart's logic transcribed to C over SDL2, its graphics and sounds in
# data/. It reads data/ from the working directory and writes its input
# settings there too, so the launcher runs it from the install directory
# and moves the settings file into the home directory.
CCLESTE_VER=1.4.0
ccleste_install() {
    _s=$(gh_source lemon32767/ccleste "v$CCLESTE_VER" \
         32dfd797f3c863201e0c19aa97974c56a8ed589a34c0522503f25f6e1399edd6) || return 1
    make -C "$_s" -j "$JOBS"
    _d="$DEST$PREFIX/lib/copal-store/ccleste"
    mkdir -p "$_d" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$_s/ccleste" "$_d/" && cp -r "$_s/data" "$_s/gamecontrollerdb.txt" "$_d/"
    cp "$_s/icon.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/ccleste.png"
    launcher ccleste <<EOF
mkdir -p "\$HOME/.local/share/ccleste"
export CCLESTE_INPUT_CFG_PATH="\$HOME/.local/share/ccleste/input-cfg.txt"
cd "$PREFIX/lib/copal-store/ccleste" && exec ./ccleste "\$@"
EOF
    desktop_entry ccleste "Celeste Classic" ccleste ccleste "Game;ActionGame;" \
        "The PICO-8 original of Celeste"
}
ccleste_bdeps() { echo "build-base sdl2-dev sdl2_mixer-dev"; }
ccleste_rdeps() { echo "sdl2 sdl2_mixer"; }
ccleste_needs() { echo ""; }
ccleste_source() { echo "github lemon32767/ccleste"; }

# ---- playbooks/Creative/darktable.sh
# darktable: a raw photo developer, CMake over GTK 3. Compiled here rather
# than taken from Alpine (5.4.1) at the owner's wish, and newer for it. The
# release archive carries its submodules -- rawspeed, LibRaw, libxcf,
# whereami -- which GitHub's tag archive does not; every other library is
# Alpine's, Lua 5.4 included (its in-tree Lua stays off).
#
# Everything useful is on: OpenMP, Lua 5.4 with the bundled lua-scripts and
# script manager, the map view, printing, tethering (gphoto2), MIDI
# controllers (PortMidi), GraphicsMagick import, and the JPEG XL, HEIF, AVIF, WebP, OpenEXR and JPEG
# 2000 formats. Exiv2 is Alpine's, built with ISOBMFF, so Canon CR3 metadata
# reads. exiftool comes along for the Lua scripts that call it, and
# iso-codes names the interface languages in preferences (its pkg-config
# file is in -dev). Lensfun's lens database arrives with the library.
#
# Left out: OpenCL (no GPU compute on a Pi or under UTM, and its build-time
# test compiles need clang), G'MIC (Alpine has it only in edge/testing, and
# a stable-branch program linked to an edge library breaks when edge moves
# on; it adds only the LUT 3D module's compressed .gmz packs -- .cube and
# PNG LUTs work without it), colord (a system daemon with polkit, only for
# reading the monitor profile automatically -- an ICC file can be chosen in
# preferences instead), KWallet (no KDE desktop), and the tests.
#
# rawspeed learns the CPU's page size by compiling a probe that tests
# _POSIX_C_SOURCE, which glibc defines by default and musl does not, so on
# Alpine the probe is an #error and configuring stops. The size is given
# instead, from getconf -- this machine's, since a Pi 5 kernel may use 16 KB
# pages -- and rawspeed then skips its probe. Its L1d cache-line probe fails
# the same way (it asks sysconf for a name only glibc has), so the line size
# is read from sysfs, or is rawspeed's own fallback of 64 where the kernel
# does not say, as under UTM. Every 64-bit core a Pi has uses 64.
DARKTABLE_VER=5.6.1
darktable_install() {
    _t=$(gh_asset darktable-org/darktable "release-$DARKTABLE_VER" "darktable-$DARKTABLE_VER.tar.xz" \
         e8b84ac98b0b689a244e4036c4b56394c1d58ce2d9abc05e0a060ef9f756dc36) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _cl=$(cat /sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size 2>/dev/null) || _cl=""
    cmake_stage "$W/darktable-$DARKTABLE_VER" -DBUILD_TESTING=OFF -DUSE_OPENCL=OFF \
        -DTESTBUILD_OPENCL_PROGRAMS=OFF -DUSE_COLORD=OFF -DUSE_KWALLET=OFF -DUSE_GMIC=OFF \
        -DUSE_XMLLINT=OFF -DBUILD_CMSTEST=OFF -DRAWSPEED_PAGESIZE="$(getconf PAGESIZE)" \
        -DRAWSPEED_CACHELINESIZE="${_cl:-64}" || return 1
}
# darktable opens a "Welcome to darktable!" dialog over its first window, once
# per home. A darktablerc holding only that flag spares it; darktable fills in
# every other setting from its defaults on the first run.
darktable_post() {
    printf 'ui/show_welcome_screen=FALSE\n' | seed_homes .config/darktable/darktablerc
}
darktable_bdeps() { echo "build-base cmake samurai pkgconf gettext-dev intltool libxslt perl gtk+3.0-dev glib-dev libxml2-dev potrace-dev libgphoto2-dev imath-dev openexr-dev libjxl-dev libwebp-dev libavif-dev libheif-dev lensfun-dev sqlite-dev curl-dev libarchive-dev exiv2-dev portmidi-dev openjpeg-dev libsecret-dev graphicsmagick-dev icu-dev lua5.4-dev pugixml-dev osm-gps-map-dev cups-dev json-glib-dev lcms2-dev libjpeg-turbo-dev tiff-dev librsvg-dev libpng-dev zlib-dev sdl2-dev iso-codes-dev"; }
darktable_rdeps() { echo "iso-codes exiftool"; }
darktable_needs() { echo ""; }
darktable_source() { echo "github darktable-org/darktable"; }

# ---- playbooks/Games/ddnet.sh
# DDNet: DDraceNetwork, the cooperative Teeworlds that outlived Teeworlds.
# CMake over C++ with one Rust library inside, which cargo builds -- its
# crates come from crates.io at build time, into a CARGO_HOME inside the
# build directory that goes when the build does. The video recorder (FFmpeg)
# and the self-updater are left out: the store is the updater.
DDNET_VER=20.0
ddnet_install() {
    _s=$(gh_source ddnet/ddnet "$DDNET_VER" \
         c4f6cca7b04e9d370fc2f187b873347b546d6e0c749c01fa7e5cd7d278c88851) || return 1
    # DATA_DIR is DDNet's own compile-time hook for where its data is; without
    # it the game looks in /usr/local/share and a few fixed places, and any
    # other prefix starts with no data at all (seen on the bench: exit 139).
    # The escaped quotes survive the sh -c that ninja runs each command in.
    CARGO_HOME="$W/cargo" CXXFLAGS="${CXXFLAGS:-} -DDATA_DIR=\\\"$PREFIX/share/ddnet/data\\\"" \
        cmake_stage "$_s" -DVIDEORECORDER=OFF -DAUTOUPDATE=OFF \
        -DINFORM_UPDATE=OFF -DPREFER_BUNDLED_LIBS=OFF -DTOOLS=OFF -DUPNP=OFF
}
ddnet_bdeps() { echo "build-base cmake samurai python3 rust cargo sdl2-dev sqlite-dev curl-dev freetype-dev libogg-dev opus-dev opusfile-dev libpng-dev wavpack-dev glslang glslang-dev vulkan-headers vulkan-loader-dev openssl-dev zlib-dev"; }
ddnet_rdeps() { echo ""; }
ddnet_needs() { echo ""; }
ddnet_source() { echo "github ddnet/ddnet"; }

# ---- playbooks/Games/devilutionx.sh
# DevilutionX: Diablo (1996), its engine reconstructed from the original and
# carried on as free software. Built from the release's fully-vendored source
# -- the libraries it fetches at build time are already in its dist/, so the
# build reaches nothing but this tarball. Alpine supplies SDL2, SDL2_image,
# zlib, bzip2, libpng and libsodium, each named ON below: a source
# distribution defaults every library to its dist/ copy, and dist/'s SDL2
# 2.30 no longer compiles against Alpine's PipeWire headers. SDL_audiolib
# (not packaged) and fmt (it wants its own major version) come from dist/.
#
# THE GAME'S DATA. The engine is free; Diablo is not. What is free is the
# 1997 shareware episode, spawn.mpq, which DevilutionX's own assets
# repository hosts on GitHub, so it plays the first two dungeon levels out
# of the box. A copied DIABDAT.MPQ (the CD or GOG) in
# ~/.local/share/diasurgical/devilution/ is found first and plays the whole
# game. The launcher puts the store's share/ at the head of XDG_DATA_DIRS,
# which is where the engine looks beyond the home directory, so spawn.mpq is
# found under any prefix.
#
# Left out: ZeroTier online play (a large vendored build; TCP multiplayer
# over a LAN stays), Discord presence, the tests, and the Hellfire menu entry,
# which needs Hellfire's own files.
DEVILUTIONX_VER=1.5.5
# sdl2-compat-static: SDL2's CMake package (sdl2-compat's, in 3.24)
# imports SDL2::SDL2main from libSDL2main.a, which only the -static
# subpackage ships, and find_package fails outright without it.
devilutionx_install() {
    _t=$(gh_asset diasurgical/devilutionX "$DEVILUTIONX_VER" devilutionx-src-fully-vendored.tar.xz \
         f42379cdf098a351a2020d9e6de1840c76e09113c792f73c6df34dec26818b04) || return 1
    _m=$(gh_asset diasurgical/devilutionx-assets v2 spawn.mpq \
         64427cd7c1ba904eaa2e0031c16a6b136d0ecef9abc888c5ff8344b459356e38) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/devilutionx-src-full-$DEVILUTIONX_VER"
    cmake_stage "$_s" -DBUILD_TESTING=OFF -DDISABLE_ZERO_TIER=ON -DDISCORD_INTEGRATION=OFF \
        -DDEVILUTIONX_SYSTEM_LIBFMT=OFF -DDEVILUTIONX_SYSTEM_SDL_AUDIOLIB=OFF \
        -DDEVILUTIONX_SYSTEM_SDL2=ON -DDEVILUTIONX_SYSTEM_SDL_IMAGE=ON -DDEVILUTIONX_SYSTEM_ZLIB=ON \
        -DDEVILUTIONX_SYSTEM_BZIP2=ON -DDEVILUTIONX_SYSTEM_LIBPNG=ON -DDEVILUTIONX_SYSTEM_LIBSODIUM=ON \
        -DDISABLE_LTO=ON || return 1
    _d="$DEST$PREFIX/share/diasurgical/devilutionx"
    mkdir -p "$_d" && cp "$_m" "$_d/spawn.mpq"
    rm -f "$DEST$PREFIX/share/applications/devilutionx-hellfire.desktop" \
          "$DEST$PREFIX/share/icons/hicolor/512x512/apps/devilutionx-hellfire.png"
    mv "$DEST$PREFIX/bin/devilutionx" "$DEST$PREFIX/share/diasurgical/devilutionx/devilutionx.bin"
    launcher devilutionx <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/share/diasurgical/devilutionx/devilutionx.bin" "\$@"
EOF
}
devilutionx_bdeps() { echo "build-base cmake samurai pkgconf sdl2-dev sdl2-compat-static sdl2_image-dev zlib-dev bzip2-dev libpng-dev libsodium-dev gettext-dev"; }
devilutionx_rdeps() { echo "sdl2 sdl2_image libsodium libbz2 zlib libpng"; }
devilutionx_needs() { echo ""; }
devilutionx_source() { echo "github diasurgical/devilutionX"; }

# ---- playbooks/Games/dxx.sh
# Descent 1 and 2, on DXX-Rebirth, which builds both engines from one tree.
# Its last tag is 2018 and the work has gone on since, so this pins a commit.
# The data are the shareware Descent and the Descent 2 demo, both freely
# distributable, as dxx-rebirth.com served them until 2022 -- that site now
# holds only its final release, so the copies come from the Wayback Machine,
# the same place Pi-Apps takes them from, pinned here by checksum. The full
# games' data dropped into ~/.d1x-rebirth or ~/.d2x-rebirth play instead.
DXX_COMMIT=e0165250820d0e11f4cb29890eb68017ea4bbb64
DXX_DATA=https://web.archive.org/web/20221208193117if_/https://www.dxx-rebirth.com/download/dxx/content
dxx_install() {
    _s=$(gh_source dxx-rebirth/dxx-rebirth "$DXX_COMMIT" \
         4e43938f718548dadbded1c0ea3687ef0ba3cef65bf894becb93c04bdd53edcb) || return 1
    # builddir stays the default, inside the tree: scons's default target is
    # '.', and a build directory elsewhere is outside it and never built.
    (cd "$_s" && nice -n 10 scons -j "$JOBS" sdl2=1 opengl=1 d1x=1 d2x=1)
    _d="$PREFIX/lib/copal-store/dxx-rebirth"
    mkdir -p "$DEST$_d/d1" "$DEST$_d/d2"
    cp "$(find "$_s/build" -type f -name d1x-rebirth | head -n1)" \
       "$(find "$_s/build" -type f -name d2x-rebirth | head -n1)" "$DEST$_d/"
    for _z in "descent-pc-shareware.zip:744b7f29043e977e7702173b150db7a6a3c253cacc9f608a0b3709acb46b51f1:d1" \
              "descent2-pc-demo.zip:b842cf983d0f393cede5cb6703186ec6eedac9bc5732dc577966f6f3122b9130:d2"; do
        _n=${_z%%:*}; _x=${_z#*:}; _sum=${_x%%:*}; _to=${_x#*:}
        _f="$CACHE/dxx-$_n"
        [ -s "$_f" ] || curl -fL --retry 3 -o "$_f" "$DXX_DATA/$_n"
        verify_sum "$_f" "$_sum"
        unzip -q -o "$_f" -d "$DEST$_d/$_to"
    done
    for _g in "d1x-rebirth:d1:Descent (shareware)" "d2x-rebirth:d2:Descent 2 (demo)"; do
        _b=${_g%%:*}; _x=${_g#*:}; _h=${_x%%:*}; _name=${_x#*:}
        launcher "$_b" <<EOF
exec "$_d/$_b" -hogdir "$_d/$_h" "\$@"
EOF
        desktop_entry "$_b" "$_name" "$_b" applications-games "Game;ActionGame;" "Six-degrees-of-freedom shooter in the mines"
    done
}
dxx_bdeps() { echo "build-base scons pkgconf sdl2-dev sdl2_mixer-dev sdl2_image-dev physfs-dev libpng-dev glu-dev mesa-dev"; }
dxx_rdeps() { echo ""; }
dxx_needs() { echo ""; }
dxx_source() { echo "github dxx-rebirth/dxx-rebirth"; }

# ---- playbooks/Games/endlesssky.sh
# Endless Sky: the 2D space trading game, CMake, in the starter set. Stage 12
# built it too, unpinned, until this replaced it; this is the one way. Its
# CMakeLists turns on link-time optimisation for Release, and GCC's LTO
# cannot inline the fortified vsnprintf on Alpine, so that line is patched
# off. SDL2 is found by its CMake package, which is
# sdl2-compat's and needs sdl2-compat-static (see DevilutionX). The binary
# installs to $PREFIX/games, which is not on Alpine's PATH; a launcher in bin
# runs it there. The game looks for its data only under /usr/local and /usr,
# so the launcher names it: under any other prefix it would stop at once,
# "Unable to find the resource directories!".
# Alpine's FLAC CMake package names /usr/bin/flac, the command-line program,
# and CMake stops when that file is absent -- which it is unless flac itself
# is installed. With the package skipped, the CMakeLists takes its own
# fallback, pkg-config's flac++, and needs nothing more.
ENDLESSSKY_VER=0.11.2
endlesssky_install() {
    _s=$(gh_source endless-sky/endless-sky "v$ENDLESSSKY_VER" \
         066b4c171fa7756b4c538a81e9926d4d7686cdbbe44fb5ab2c83e137a7493278) || return 1
    sed -i 's/^set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)/set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE FALSE)/' \
        "$_s/CMakeLists.txt"
    cmake_stage "$_s" -DES_USE_VCPKG=OFF -DBUILD_TESTING=OFF -DCMAKE_DISABLE_FIND_PACKAGE_FLAC=ON || return 1
    launcher endless-sky <<EOF
exec "$PREFIX/games/endless-sky" --resources "$PREFIX/share/games/endless-sky" "\$@"
EOF
}
endlesssky_bdeps() { echo "build-base cmake samurai pkgconf sdl2-dev sdl2-compat-static libpng-dev libjpeg-turbo-dev libavif-dev glew-dev openal-soft-dev flac-dev zlib-dev minizip-dev util-linux-dev mesa-dev"; }
endlesssky_rdeps() { echo ""; }
endlesssky_needs() { echo ""; }
endlesssky_source() { echo "github endless-sky/endless-sky"; }

# ---- playbooks/Tools/ffconverter.sh
# FF Multi Converter: a PyQt5 front end to ffmpeg, ImageMagick, unoconv and
# pandoc, whichever are present. pip installs it from the source tree into a
# private target directory -- --no-deps, so pip fetches nothing.
FFCONVERTER_VER=2.4.6
ffconverter_install() {
    _s=$(gh_source l-koehler/FF-converter "v$FFCONVERTER_VER" \
         41c8b93151464ef12aa35ec5f77fed52c2998ed05f0cd564aab6ca344ea73388) || return 1
    _t="$PREFIX/lib/copal-store/ffconverter"
    # It looks for presets.xml under /usr/local/share and /usr/share; the
    # prefix it was installed to goes first.
    sed -i "s|presets_lookup_dirs = \\[|presets_lookup_dirs = [\"$PREFIX/share/\", |" "$_s/ffconverter/config.py"
    pip3 install --no-deps --no-build-isolation --no-compile --break-system-packages \
         --target "$DEST$_t" "$_s"
    rm -rf "$DEST$_t/bin" "$DEST$_t/share"
    mkdir -p "$DEST$PREFIX/share/ffconverter" "$DEST$PREFIX/share/icons/hicolor/128x128/apps"
    cp "$_s/share/presets.xml" "$DEST$PREFIX/share/ffconverter/"
    cp "$_s/share/ffconverter.png" "$DEST$PREFIX/share/icons/hicolor/128x128/apps/"
    launcher ffconverter <<EOF
export PYTHONPATH="$_t\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -c 'import sys; from ffconverter.ffconverter import main; sys.exit(main())' "\$@"
EOF
    desktop_entry ffconverter "FF Multi Converter" ffconverter ffconverter "Utility;AudioVideo;" \
        "Convert audio, video, image and document files"
}
ffconverter_bdeps() { echo "py3-pip py3-setuptools py3-wheel"; }
ffconverter_rdeps() { echo "python3 py3-qt5 ffmpeg imagemagick"; }
ffconverter_needs() { echo ""; }
ffconverter_source() { echo "github l-koehler/FF-converter"; }

# ---- playbooks/Documents/focuswriter.sh
# FocusWriter: a full-screen writing program, CMake over Qt 6 and Hunspell.
# Nothing to repair; Alpine has every library, KDSingleApplication included.
FOCUSWRITER_VER=1.9.1
focuswriter_install() {
    _s=$(gh_source gottcode/focuswriter "v$FOCUSWRITER_VER" \
         ca83cade13158111e19eeba86d0a043bb45be4f32bd82f43da2bb910c0edd32d) || return 1
    cmake_stage "$_s" || return 1
}
focuswriter_bdeps() { echo "build-base cmake samurai pkgconf qt6-qtbase-dev qt6-qttools-dev qt6-qtmultimedia-dev hunspell-dev kdsingleapplication-dev zlib-dev"; }
focuswriter_rdeps() { echo "hunspell-en"; }
focuswriter_needs() { echo ""; }
focuswriter_source() { echo "github gottcode/focuswriter"; }

# ---- playbooks/Science/fraqtive.sh
# Fraqtive, a Mandelbrot-family fractal generator, at its last release,
# 0.4.8.1. qmake over Qt 5, with Qt's OpenGL module for its 3D view of the set
# as a landscape. On aarch64 Alpine's Qt 5 is built for OpenGL ES, and the 3D
# view draws only black there (seen on the bench, 23 Sep 2026); the 2D view,
# drawn by the CPU, is the program, and works.
FRAQTIVE_VER=0.4.8.1
fraqtive_install() {
    _s=$(gh_source mimecorg/fraqtive "v$FRAQTIVE_VER" \
         f3e152e15072f6cbecf100d748f21e4e7a48eace77b93d7daf837ea86491b46b) || return 1
    mkdir -p "$W/build"
    # LIBS: its 3D view calls desktop GL (glRotated and the rest), which Qt 5
    # built for OpenGL ES does not link in; libGL and libGLU are named.
    (cd "$W/build" && qmake-qt5 "$_s/fraqtive.pro" PREFIX="$PREFIX" CONFIG+=release \
        QMAKE_LFLAGS+="-Wl,-z,stack-size=8388608" LIBS+="-lGL -lGLU" \
       && nice -n 10 make -j "$JOBS" && make INSTALL_ROOT="$DEST" install) || return 1
}
fraqtive_bdeps() { echo "build-base qt5-qtbase-dev mesa-dev glu-dev"; }
fraqtive_rdeps() { echo ""; }
fraqtive_needs() { echo ""; }
fraqtive_source() { echo "github mimecorg/fraqtive"; }

# ---- playbooks/Games/funkin.sh
# Friday Night Funkin' Rewritten, a LOVE game: its source tree, zipped, is the
# game file LOVE runs. The release's images are already in the tree.
FUNKIN_VER=1.1.0-beta.2-1
funkin_install() {
    _s=$(gh_source HTV04/funkin-rewritten "v$FUNKIN_VER" \
         5563f4096234f3b2b108bbfcf69f5fdc4fa5b77b4dbc680eb86a6876d837d8fa) || return 1
    _d="$PREFIX/lib/copal-store/funkin"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/256x256/apps"
    (cd "$_s/src/love" && zip -q -r -9 "$DEST$_d/funkin-rewritten.love" .)
    cp "$_s/src/love/icons/default.png" "$DEST$PREFIX/share/icons/hicolor/256x256/apps/funkin-rewritten.png"
    launcher funkin-rewritten <<EOF
exec love "$_d/funkin-rewritten.love" "\$@"
EOF
    desktop_entry funkin-rewritten "Friday Night Funkin' Rewritten" funkin-rewritten funkin-rewritten \
        "Game;MusicGame;" "Rhythm battles, arrow keys to the beat"
}
funkin_bdeps() { echo "zip"; }
funkin_rdeps() { echo "love"; }
funkin_needs() { echo ""; }
funkin_source() { echo "github HTV04/funkin-rewritten"; }

# ---- playbooks/Games/kmahjongg.sh
# KMahjongg, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Its tiles and layouts come from libkmahjongg, which Alpine packages.
KMAHJONGG_VER=26.04.3
kmahjongg_install() {
    _s=$(gh_source KDE/kmahjongg "v$KMAHJONGG_VER" \
         891b17cae420fd5d7b07efac7a4bbf5883c17a5a35d027d0fab8eb3897ebcf22) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kmahjongg"
    mv "$DEST$PREFIX/bin/kmahjongg" "$DEST$PREFIX/lib/copal-store/kmahjongg/kmahjongg"
    launcher kmahjongg <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kmahjongg/kmahjongg" "\$@"
EOF
}
kmahjongg_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev kxmlgui-dev libkdegames-dev knewstuff-dev libkmahjongg-dev"; }
kmahjongg_rdeps() { echo "libkdegames libkmahjongg"; }
kmahjongg_needs() { echo ""; }
kmahjongg_source() { echo "github KDE/kmahjongg"; }

# ---- playbooks/Games/konquest.sh
# Konquest, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# the KDE Gear release that matches Alpine's libkdegames -- 26.04 -- so the
# game and the games library it links are one release series. Alpine packages
# libkdegames and every KDE Framework it needs, but not the game: the whole
# of kdegames is absent from v3.24 but for its library.
#
# StateMachine is Qt's SCXML module (qt6-qtscxml); ColorScheme is
# kcolorscheme. The handbook is built by kdoctools and installed with it, and
# the game's data goes under share/, where KDE programs look for it through
# XDG_DATA_DIRS -- which the launcher puts the store's prefix at the head of,
# so it is found under any prefix, not only /usr/local.
KONQUEST_VER=26.04.3
konquest_install() {
    _s=$(gh_source KDE/konquest "v$KONQUEST_VER" \
         b7451664cc8fe01f6596d150f24ac01e290fb7ea38020180cb5f451fdd060db2) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/konquest"
    mv "$DEST$PREFIX/bin/konquest" "$DEST$PREFIX/lib/copal-store/konquest/konquest"
    launcher konquest <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/konquest/konquest" "\$@"
EOF
}
konquest_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev qt6-qtscxml-dev kcolorscheme-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev kguiaddons-dev ki18n-dev kwidgetsaddons-dev kxmlgui-dev libkdegames-dev"; }
konquest_rdeps() { echo "libkdegames"; }
konquest_needs() { echo ""; }
konquest_source() { echo "github KDE/konquest"; }

# ---- playbooks/Emulation/kretro.sh
# KRetro, KDE's front end for Libretro emulator cores, at its first release,
# v0.0.1: a work in progress, as its own README says. Kirigami and Qt Quick,
# with SDL3 for controllers. It plays games through Libretro cores, which it
# does not bring; RetroArch, in the catalogue, is the finished way to play.
KRETRO_VER=0.0.1
kretro_install() {
    _s=$(gh_source KDE/kretro "v$KRETRO_VER" \
         7adc6b56c512acf911040f8501b98c0f052425413266e33222ea8e756e2ffae0) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
}
kretro_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtdeclarative-dev qt6-qtsvg-dev qt6-qtmultimedia-dev kirigami-dev kirigami-addons-dev kcoreaddons-dev kconfig-dev ki18n-dev sdl3-dev"; }
kretro_rdeps() { echo "kirigami kirigami-addons"; }
kretro_needs() { echo ""; }
kretro_source() { echo "github KDE/kretro"; }

# ---- playbooks/Games/kreversi.sh
# KReversi, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Its board is drawn in Qt Quick, so it needs Qt's QML modules to build.
KREVERSI_VER=26.04.3
kreversi_install() {
    _s=$(gh_source KDE/kreversi "v$KREVERSI_VER" \
         67f41e49cf6f6b30b989d7d1b4a7feea5241c70584085902fb78976ffb6c6702) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kreversi"
    mv "$DEST$PREFIX/bin/kreversi" "$DEST$PREFIX/lib/copal-store/kreversi/kreversi"
    launcher kreversi <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kreversi/kreversi" "\$@"
EOF
}
kreversi_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev kxmlgui-dev libkdegames-dev qt6-qtdeclarative-dev kcolorscheme-dev kconfigwidgets-dev kiconthemes-dev kjobwidgets-dev kio-dev kwidgetsaddons-dev"; }
kreversi_rdeps() { echo "libkdegames"; }
kreversi_needs() { echo ""; }
kreversi_source() { echo "github KDE/kreversi"; }

# ---- playbooks/Games/ksnakeduel.sh
# KSnakeDuel, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
KSNAKEDUEL_VER=26.04.3
ksnakeduel_install() {
    _s=$(gh_source KDE/ksnakeduel "v$KSNAKEDUEL_VER" \
         552fc2b130327738d75003b6e6c46118fabf5c726b880e8c32290845a35b5e33) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/ksnakeduel"
    mv "$DEST$PREFIX/bin/ksnakeduel" "$DEST$PREFIX/lib/copal-store/ksnakeduel/ksnakeduel"
    launcher ksnakeduel <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/ksnakeduel/ksnakeduel" "\$@"
EOF
}
ksnakeduel_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev kxmlgui-dev libkdegames-dev kcompletion-dev kconfigwidgets-dev kguiaddons-dev kiconthemes-dev kwidgetsaddons-dev"; }
ksnakeduel_rdeps() { echo "libkdegames"; }
ksnakeduel_needs() { echo ""; }
ksnakeduel_source() { echo "github KDE/ksnakeduel"; }

# ---- playbooks/Games/kspaceduel.sh
# KSpaceDuel, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
KSPACEDUEL_VER=26.04.3
kspaceduel_install() {
    _s=$(gh_source KDE/kspaceduel "v$KSPACEDUEL_VER" \
         d62c62684f12b6c4d78fbba84c8572e9379a3aa04fb032297dabd01afc63d659) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kspaceduel"
    mv "$DEST$PREFIX/bin/kspaceduel" "$DEST$PREFIX/lib/copal-store/kspaceduel/kspaceduel"
    launcher kspaceduel <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kspaceduel/kspaceduel" "\$@"
EOF
}
kspaceduel_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev kxmlgui-dev libkdegames-dev kconfigwidgets-dev"; }
kspaceduel_rdeps() { echo "libkdegames"; }
kspaceduel_needs() { echo ""; }
kspaceduel_source() { echo "github KDE/kspaceduel"; }

# ---- playbooks/Games/kubrick.sh
# Kubrick, from KDE's own repository (the GitHub mirror of invent.kde.org), at
# KDE Gear 26.04.3 -- the release series of Alpine's libkdegames, so the game
# and the games library it links are one series. Built like Konquest: its data
# goes under share/ and the launcher puts the store's share/ at the head of
# XDG_DATA_DIRS, so it is found under any prefix.
# Kubrick draws with fixed-function OpenGL (GL/gl.h, GLU) inside a Qt
# OpenGL widget. Alpine's aarch64 Qt is built for OpenGL ES, which stopped
# OpenToonz and blanks Fraqtive's 3D view -- but Kubrick's cube draws, shaded,
# front and back (seen on the bench, 23 Sep 2026).
KUBRICK_VER=26.04.3
kubrick_install() {
    _s=$(gh_source KDE/kubrick "v$KUBRICK_VER" \
         105f00cf36916abba2666db37a65302e835996eaf6788059917796726d20b68b) || return 1
    cmake_stage "$_s" -DBUILD_TESTING=OFF || return 1
    mkdir -p "$DEST$PREFIX/lib/copal-store/kubrick"
    mv "$DEST$PREFIX/bin/kubrick" "$DEST$PREFIX/lib/copal-store/kubrick/kubrick"
    launcher kubrick <<EOF
export XDG_DATA_DIRS="$PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$PREFIX/lib/copal-store/kubrick/kubrick" "\$@"
EOF
}
kubrick_bdeps() { echo "build-base cmake samurai extra-cmake-modules gettext-dev qt6-qtbase-dev qt6-qtsvg-dev kconfig-dev kcoreaddons-dev kcrash-dev kdbusaddons-dev kdoctools-dev ki18n-dev kxmlgui-dev libkdegames-dev kconfigwidgets-dev kwidgetsaddons-dev glu-dev mesa-dev"; }
kubrick_rdeps() { echo "libkdegames glu"; }
kubrick_needs() { echo ""; }
kubrick_source() { echo "github KDE/kubrick"; }

# ---- playbooks/Engineering/librecad.sh
# LibreCAD: 2D CAD, CMake over Qt 5, with muParser in its own tree. Its crash
# handler includes glibc's <execinfo.h>; the patch gives musl empty stubs.
LIBRECAD_VER=2.2.1.5
librecad_install() {
    _s=$(gh_source LibreCAD/LibreCAD "v$LIBRECAD_VER" \
         703f6e6701b7ee47769b6def271fa025ef32e31ee193e2ba69a2c47fff8da459) || return 1
    apply_patch "$_s" patch_librecad_musl
    cmake_stage "$_s"
}
# Its first start asks for a unit and a language before drawing anything.
# Millimetres, and the language the desktop is in.
librecad_post() {
    seed_homes .config/LibreCAD/LibreCAD.conf <<'EOF'
[Startup]
FirstLoad=0

[Defaults]
Unit=Millimeter
EOF
}

patch_librecad_musl() {
    cat <<'PATCH'
--- a/librecad/src/lib/debug/lc_crashhandler.cpp
+++ b/librecad/src/lib/debug/lc_crashhandler.cpp
@@ -49,7 +49,13 @@
 #  include <sys/stat.h>
 #else
 #  include <csignal>
-#  include <execinfo.h>
+#  if __has_include(<execinfo.h>)
+#    include <execinfo.h>
+#  else
+     // copal: musl has no execinfo.h; the crash log goes without a stack trace.
+     static inline int backtrace(void**, int) { return 0; }
+     static inline void backtrace_symbols_fd(void* const*, int, int) {}
+#  endif
 #  include <fcntl.h>
 #  include <sys/types.h>
 #  include <unistd.h>
PATCH
}
librecad_bdeps() { echo "build-base cmake samurai qt5-qtbase-dev qt5-qtsvg-dev qt5-qttools-dev boost-dev freetype-dev"; }
librecad_rdeps() { echo "qt5-qtsvg"; }
librecad_needs() { echo ""; }
librecad_source() { echo "github LibreCAD/LibreCAD"; }

# ---- playbooks/Games/naev.sh
# Naev: 2D space trading and combat with a long written story, meson. The
# release's source archive carries the game's data (most of its 444 MB).
# Every library comes from Alpine -- LuaJIT, SuiteSparse, GLPK and OpenBLAS
# for its fleet physics and economy among them -- except the file dialog,
# nativefiledialog-extended, which Alpine does not package and meson would
# fetch from its wrap while configuring. Instead both of that wrap's files
# come from wrapdb's own GitHub release through gh_asset, pinned by the
# hashes Naev's .wrap names, and are put in subprojects/packagecache, where
# meson finds them with downloads switched off. Its portal backend is used
# (D-Bus to xdg-desktop-portal) rather than GTK 3, which it would otherwise
# pull in whole for one dialog. Naev finds SuiteSparse's libraries but not its
# headers, which Alpine keeps in their own directory; pkg-config knows which.
# Linked for glibc-sized thread stacks, as cmake_stage does: Naev loads its
# textures on worker threads, and under Mesa's software renderer the first
# upload JIT-compiles a shader there, which overflowed musl's 128 KB.
NAEV_VER=0.12.6
NAEV_NFDE_WRAP=nativefiledialog-extended_1.2.1-1
naev_install() {
    _t=$(gh_asset naev/naev "v$NAEV_VER" "naev-$NAEV_VER-source.tar.xz" \
         e81c0e25630146f3a709a540679a75c0af4983f858184130ebac5c6ba7d4592a) || return 1
    _n=$(gh_asset mesonbuild/wrapdb "$NAEV_NFDE_WRAP" nativefiledialog-extended-1.2.1.tar.gz \
         443697a857c4efacbe08cdaf5182724fa9d9b9a79b8feff2a1601bde1df46b07) || return 1
    _p=$(gh_asset mesonbuild/wrapdb "$NAEV_NFDE_WRAP" "${NAEV_NFDE_WRAP}_patch.zip" \
         044a2e881d874d55a892b61cf553aa7678d1c0f06cfaeb39a1b43f34ca976b09) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/naev-$NAEV_VER"
    mkdir -p "$_s/subprojects/packagecache"
    cp "$_n" "$_s/subprojects/packagecache/nativefiledialog-extended-1.2.1.tar.gz"
    cp "$_p" "$_s/subprojects/packagecache/${NAEV_NFDE_WRAP}_patch.zip"
    LDFLAGS="${LDFLAGS:-} -Wl,-z,stack-size=8388608" \
    meson setup "$W/build" "$_s" --prefix="$PREFIX" --buildtype=release --wrap-mode=nodownload \
        -Dc_args="$(pkg-config --cflags-only-I CHOLMOD)" -Dluajit=enabled -Ddocs_c=disabled -Ddocs_lua=disabled \
        -Dnativefiledialog-extended:xdg-desktop-portal=enabled
    meson compile -C "$W/build" -j "$JOBS"
    DESTDIR="$DEST" meson install -C "$W/build"
}
naev_bdeps() { echo "build-base meson samurai pkgconf sdl2-dev sdl2_image-dev enet-dev pcre2-dev libunibreak-dev cmark-dev yaml-dev libxml2-dev physfs-dev freetype-dev libpng-dev libwebp-dev luajit-dev glpk-dev suitesparse-dev openblas-dev openal-soft-dev libvorbis-dev libogg-dev gettext-dev dbus-dev py3-yaml"; }
naev_rdeps() { echo ""; }
naev_needs() { echo ""; }
naev_source() { echo "github naev/naev"; }

# ---- playbooks/Appearance/ohmyposh.sh
# Oh My Posh: prompt themes for any shell, Go. Held at 30.9.0, the last
# release whose go.mod accepts Alpine 3.24's Go 1.26; 31.0 wants 1.27, and
# the alternative -- GOTOOLCHAIN fetching a newer Go -- downloads a compiler
# from outside GitHub and outside apk. The modules come from the Go
# proxy at build time into a cache inside the build directory, which goes
# when the build does. The themes are installed beside it:
#   eval "$(oh-my-posh init bash --config /usr/local/share/oh-my-posh/themes/jandedobbeleer.omp.json)"
OHMYPOSH_VER=30.9.0
ohmyposh_install() {
    _s=$(gh_source JanDeDobbeleer/oh-my-posh "v$OHMYPOSH_VER" \
         1f883716db56729bc2c97703673758892917502a81e844e2f6305067ebf968ce) || return 1
    mkdir -p "$DEST$PREFIX/bin" "$DEST$PREFIX/share/oh-my-posh"
    (cd "$_s/src" && GOPATH="$W/go" GOCACHE="$W/gocache" GOFLAGS=-modcacherw CGO_ENABLED=0 \
        go build -trimpath -o "$DEST$PREFIX/bin/oh-my-posh" \
        -ldflags "-s -w -X github.com/jandedobbeleer/oh-my-posh/src/build.Version=$OHMYPOSH_VER")
    cp -r "$_s/themes" "$DEST$PREFIX/share/oh-my-posh/"
}
ohmyposh_bdeps() { echo "go"; }
ohmyposh_rdeps() { echo ""; }
ohmyposh_needs() { echo ""; }
ohmyposh_source() { echo "github JanDeDobbeleer/oh-my-posh"; }

# ---- playbooks/Multimedia/openshot.sh
# OpenShot, from its three repositories at matching releases. Verified on the
# aarch64 bench, 23 Sep 2026 -- openshot-qt opened its main window.
#
# The three musl repairs, all in upstream code that assumes glibc:
#   * <execinfo.h>, for a crash handler's stack trace, in both libraries.
#     musl has none; the stubs report zero frames, which both callers
#     already handle.
#   * _NL_ADDRESS_LANG_AB and _NL_ADDRESS_COUNTRY_AB2: glibc's own
#     nl_langinfo items. JUCE's BSD branch reads $LANG instead; musl joins it.
#   * stat64: musl 1.2.4 declares the LFS64 names only when asked;
#     cmake_stage passes -D_LARGEFILE64_SOURCE to every recipe.
# And one upstream slip that is not about musl: libopenshot 1.0.0 draws its
# tracked-object mask with a class that is compiled only WITH OpenCV, so a
# build without OpenCV fails to link. Guarded; without OpenCV there are no
# tracked objects to draw.
#
# OpenCV is left out: it would add the Tracker and Object Detection effects
# at the cost of ~150 MB of libraries. openshot-qt 4.0 needs no QtWebEngine;
# its timeline is a plain widget now.
OPENSHOT_VER=1.0.0
OPENSHOT_QT_VER=4.0.0
openshot_install() {
    _pyd="$PREFIX/lib/copal-store/openshot/python"
    _a=$(gh_source OpenShot/libopenshot-audio "v$OPENSHOT_VER" \
         80dc23fff901064194fcc7732d41cc953df6b7ed2742376fcf28df23b5a10a29) || return 1
    apply_patch "$_a" patch_juce_musl || return 1
    cmake_stage "$_a" \
        -DENABLE_AUDIO_DOCS=OFF -DAUTO_INSTALL_DOCS=OFF || return 1

    _l=$(gh_source OpenShot/libopenshot "v$OPENSHOT_VER" \
         5c5f3790f6f70977f3573b9d039372d5b85bddc46f8944244a6225a79891acf2) || return 1
    apply_patch "$_l" patch_libopenshot_musl || return 1
    cmake_stage "$_l" \
        -DOpenShotAudio_ROOT="$DEST$PREFIX" \
        -DENABLE_LIB_DOCS=OFF -DBUILD_TESTING=OFF -DENABLE_OPENCV=OFF \
        -DENABLE_MAGICK=OFF -DPYTHON_MODULE_PATH="${_pyd#"$PREFIX"/}" || return 1

    _q=$(gh_source OpenShot/openshot-qt "v$OPENSHOT_QT_VER" \
         97cf3d02392527d3f386ee97724828587ba1b1badee40879269ec32fe551ae6e) || return 1
    rm -f "$DEST$PREFIX/bin/openshot-audio-demo"   # JUCE's test tone player, not a program for the menu
    mkdir -p "$DEST$PREFIX/share/openshot-qt" "$DEST$PREFIX/share/icons/hicolor/scalable/apps"
    cp -a "$_q/src/." "$DEST$PREFIX/share/openshot-qt/"
    cp "$_q/xdg/openshot-qt.svg" "$DEST$PREFIX/share/icons/hicolor/scalable/apps/"
    # Alpine's Python does not look in /usr/local, and the module is kept in
    # a directory of its own besides, so nothing else can import it by chance.
    launcher openshot-qt <<EOF
export PYTHONPATH="$_pyd\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$PREFIX/share/openshot-qt/launch.py" "\$@"
EOF
    desktop_entry openshot-qt "OpenShot Video Editor" "openshot-qt %F" openshot-qt \
        "AudioVideo;Video;AudioVideoEditing;" "Edit videos: tracks, titles, transitions"
}
# The welcome tutorial and the "send anonymous metrics?" question, both on
# every first start. The settings file is merged key by key over OpenShot's
# defaults, so two keys are a whole settings file.
openshot_post() {
    seed_homes .openshot_qt/openshot.settings <<'EOF'
[
 {"setting": "send_metrics", "value": false},
 {"setting": "tutorial_enabled", "value": false}
]
EOF
}

patch_juce_musl() {
    cat <<'PATCH'
--- a/JuceLibraryCode/modules/juce_core/juce_core.cpp
+++ b/JuceLibraryCode/modules/juce_core/juce_core.cpp
@@ -103,7 +103,13 @@
  #include <sys/ioctl.h>
 
  #if ! (JUCE_ANDROID || JUCE_WASM)
-  #include <execinfo.h>
+  #if __has_include(<execinfo.h>)
+   #include <execinfo.h>
+  #else
+   // copal: musl has no execinfo.h; an empty stack trace instead.
+   static inline int backtrace (void**, int) { return 0; }
+   static inline char** backtrace_symbols (void* const*, int) { return nullptr; }
+  #endif
  #endif
 #endif
 
--- a/JuceLibraryCode/modules/juce_core/native/juce_SystemStats_linux.cpp
+++ b/JuceLibraryCode/modules/juce_core/native/juce_SystemStats_linux.cpp
@@ -198,7 +198,7 @@
 
 String SystemStats::getUserLanguage()
 {
-   #if JUCE_BSD
+   #if JUCE_BSD || ! defined (__GLIBC__)  // copal: musl has no _NL_ADDRESS_* items
     if (auto langEnv = getenv ("LANG"))
         return String::fromUTF8 (langEnv).upToLastOccurrenceOf (".UTF-8", false, true);
 
@@ -210,7 +210,7 @@
 
 String SystemStats::getUserRegion()
 {
-   #if JUCE_BSD
+   #if JUCE_BSD || ! defined (__GLIBC__)  // copal: musl has no _NL_ADDRESS_* items
     return {};
    #else
     return getLocaleValue (_NL_ADDRESS_COUNTRY_AB2);
PATCH
}

patch_libopenshot_musl() {
    cat <<'PATCH'
--- a/src/CrashHandler.h
+++ b/src/CrashHandler.h
@@ -20,8 +20,12 @@
 	#include <winsock2.h>
 	#include <windows.h>
 	#include <DbgHelp.h>
-#else
+#elif __has_include(<execinfo.h>)
 	#include <execinfo.h>
+#else
+	// copal: musl has no execinfo.h; report no frames, which the handler already handles.
+	static inline int backtrace(void**, int) { return 0; }
+	static inline char** backtrace_symbols(void* const*, int) { return nullptr; }
 #endif
 #include <errno.h>
 #include <cxxabi.h>
--- a/src/AudioLocation.h
+++ b/src/AudioLocation.h
@@ -13,6 +13,8 @@
 #ifndef OPENSHOT_AUDIOLOCATION_H
 #define OPENSHOT_AUDIOLOCATION_H
 
+#include <cstdint>  // copal: glibc brings this in transitively, musl does not
+
 
 namespace openshot
 {
--- a/src/EffectBase.cpp
+++ b/src/EffectBase.cpp
@@ -550,6 +550,9 @@
 std::shared_ptr<QImage> EffectBase::TrackedObjectMask(std::shared_ptr<QImage> target_image, int64_t frame_number) const {
 	if (!target_image || target_image->isNull() || trackedObjects.empty())
 		return {};
+#ifndef USE_OPENCV
+	return {};  // copal: tracked boxes exist only in OpenCV builds
+#else
 
 	auto mask_image = std::make_shared<QImage>(
 		target_image->width(), target_image->height(), QImage::Format_RGBA8888_Premultiplied);
@@ -595,6 +598,7 @@
 	if (!drew_any_box)
 		return {};
 	return mask_image;
+#endif
 }
 
 void EffectBase::BlendWithMask(std::shared_ptr<QImage> original_image, std::shared_ptr<QImage> effected_image,
PATCH
}
openshot_bdeps() { echo "build-base cmake samurai swig python3-dev qt6-qtbase-dev qt6-qtsvg-dev ffmpeg-dev zeromq-dev cppzmq jsoncpp-dev alsa-lib-dev babl-dev"; }
openshot_rdeps() { echo "py3-qt6 py3-pyzmq py3-requests py3-defusedxml qt6-qtsvg ffmpeg-libavcodec ffmpeg-libavformat ffmpeg-libswscale ffmpeg-libswresample jsoncpp libzmq"; }
openshot_needs() { echo ""; }
openshot_source() { echo "github OpenShot/libopenshot-audio"; }

# ---- playbooks/Games/opentyrian.sh
# OpenTyrian: the 1995 shooter Tyrian 2000's engine, ported to C over SDL2.
# The engine is compiled from the tagged source; the game's data -- freeware
# since 2004 -- comes from the same release's Linux archive, which is the only
# copy on GitHub (the README's other link is camanis.net). Only its data/
# directory is used, and it is the same for every architecture, so the arm64
# archive is fetched on all of them.
OPENTYRIAN_VER=v2.1.20260913
opentyrian_install() {
    _s=$(gh_source opentyrian/opentyrian "$OPENTYRIAN_VER" \
         dbcd96383d4fa571137242c36bd7eca054cf5a08a9bf2eec15ef230d6e60680d) || return 1
    _a=$(gh_asset opentyrian/opentyrian "$OPENTYRIAN_VER" "opentyrian-$OPENTYRIAN_VER-linux-arm64.tar.gz" \
         8608e68622edcabd30eb62fcbdfd8106982c13e29fb775ccccf56956dccd90fb) || return 1
    # VCS_IDREV: the tarball is not a git checkout, so the version is given.
    make -C "$_s" -j "$JOBS" prefix="$PREFIX" VCS_IDREV="echo $OPENTYRIAN_VER" \
        && make -C "$_s" prefix="$PREFIX" VCS_IDREV="echo $OPENTYRIAN_VER" DESTDIR="$DEST" install \
        || return 1
    _g="$DEST$PREFIX/share/games/tyrian"
    mkdir -p "$_g"
    tar -xzf "$_a" -C "$W" opentyrian/data && cp "$W"/opentyrian/data/* "$_g/"
}
opentyrian_bdeps() { echo "build-base pkgconf sdl2-dev sdl2_net-dev"; }
opentyrian_rdeps() { echo "sdl2 sdl2_net"; }
opentyrian_needs() { echo ""; }
opentyrian_source() { echo "github opentyrian/opentyrian"; }

# ---- playbooks/Games/pacman.sh
# Pac-Man, ebuc99's SDL2 clone, autotools with the configure script shipped.
# Installed as pacman-game: /usr/local/bin/pacman would shadow Arch's package
# manager, which Alpine also packages as 'pacman'.
PACMAN_VER=0.9
pacman_install() {
    _s=$(gh_source ebuc99/pacman "v$PACMAN_VER" \
         e0a8fd6d9919b16a539e06c7d3c12bc1bfd41f867366bf8dad72b49f37f8422b) || return 1
    # The data directory is written into platform.cpp as /usr/local/share,
    # beside the PACKAGE_DATA_DIR that Makefile.am already passes in.
    sed -i 's|"/usr/local/share/pacman/"|PACKAGE_DATA_DIR "/"|' "$_s/src/platform.cpp"
    (cd "$_s" && ./configure --prefix="$PREFIX" && make -j "$JOBS" && make DESTDIR="$DEST" install)
    mv "$DEST$PREFIX/bin/pacman" "$DEST$PREFIX/bin/pacman-game"
}
pacman_bdeps() { echo "build-base sdl2-dev sdl2_image-dev sdl2_ttf-dev sdl2_mixer-dev"; }
pacman_rdeps() { echo "sdl2 sdl2_image sdl2_ttf sdl2_mixer"; }
pacman_needs() { echo ""; }
pacman_source() { echo "github ebuc99/pacman"; }

# ---- playbooks/Creative/pencil2d.sh
# Pencil2D: frame-by-frame 2D animation, qmake over Qt 6. Its movie export
# runs ffmpeg by name, so ffmpeg is a runtime dependency no ELF header shows.
PENCIL2D_VER=0.7.2
pencil2d_install() {
    _s=$(gh_source pencil2d/pencil "v$PENCIL2D_VER" \
         22af8bf304cd18ae5d7a84e66d80ea2a21a53963476ffabb60d1d5f37f091a0c) || return 1
    mkdir -p "$W/build"
    (cd "$W/build" && qmake6 "$_s/pencil2d.pro" PREFIX="$PREFIX" CONFIG+=release CONFIG+=NO_TESTS \
         QMAKE_LFLAGS+="-Wl,-z,stack-size=8388608" \
       && nice -n 10 make -j "$JOBS" && make INSTALL_ROOT="$DEST" install) || return 1
}
pencil2d_bdeps() { echo "build-base qt6-qtbase-dev qt6-qtsvg-dev qt6-qtmultimedia-dev qt6-qttools-dev"; }
pencil2d_rdeps() { echo "ffmpeg"; }
pencil2d_needs() { echo ""; }
pencil2d_source() { echo "github pencil2d/pencil"; }

# ---- playbooks/Transfer/persepolis.sh
# Persepolis: meson, with its Python package steered into a private directory
# by meson's own python.purelibdir option. It drives aria2 for the transfers
# and yt-dlp for video pages.
PERSEPOLIS_VER=5.2.0
persepolis_install() {
    _s=$(gh_source persepolisdm/persepolis "$PERSEPOLIS_VER" \
         8d002e369955fd77e5353714185ce3edb98463b7117a26583b72f4db4e51b2c8) || return 1
    _py="lib/copal-store/persepolis/python"
    # Its install script checks for the dependencies by importing them, and
    # fails the install when one is missing -- which on a staging build is
    # the wrong moment to ask. apk has already been told what to install.
    sed -i "/add_install_script('check_dependencies.py')/d" "$_s/meson.build"
    meson setup "$W/build" "$_s" --prefix="$PREFIX" -Dpython.purelibdir="$_py" -Dpython.platlibdir="$_py"
    meson compile -C "$W/build"
    DESTDIR="$DEST" meson install -C "$W/build"
    mv "$DEST$PREFIX/bin/persepolis" "$DEST$PREFIX/lib/copal-store/persepolis/persepolis"
    launcher persepolis <<EOF
export PYTHONPATH="$PREFIX/$_py\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$PREFIX/lib/copal-store/persepolis/persepolis" "\$@"
EOF
}
persepolis_bdeps() { echo "meson samurai"; }
persepolis_rdeps() { echo "python3 py3-pyside6 py3-psutil py3-requests py3-setproctitle aria2 yt-dlp ffmpeg libnotify"; }
persepolis_needs() { echo ""; }
persepolis_source() { echo "github persepolisdm/persepolis"; }

# ---- playbooks/Creative/pixelorama.sh
# Pixelorama: a pixel-art editor written in Godot, run as a Godot project by
# Alpine's Godot. Held at 1.2, the last release made for Godot 4.6, which is
# what edge/testing carries; 1.2.1 on want 4.7. A Godot project imports its
# assets into a cache inside itself on first run, and /usr/local is not
# writable by the person running it, so the import is done here, at build
# time, and the project is installed already imported.
PIXELORAMA_VER=1.2
pixelorama_install() {
    _s=$(gh_source Orama-Interactive/Pixelorama "v$PIXELORAMA_VER" \
         45accd447b0561003bf484725326df48223bdab9e695a1a510f9ac5ff82afd06) || return 1
    HOME="$W/home" XDG_DATA_HOME="$W/home/data" XDG_CONFIG_HOME="$W/home/config" \
        godot --headless --path "$_s" --import
    [ -d "$_s/.godot/imported" ] || { echo "the Godot import made no cache"; return 1; }
    _d="$PREFIX/lib/copal-store/pixelorama"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/256x256/apps"
    cp -r "$_s/." "$DEST$_d/"
    rm -rf "$DEST$_d/.github" "$DEST$_d/Misc"
    cp "$_s/assets/graphics/icons/icon.png" "$DEST$PREFIX/share/icons/hicolor/256x256/apps/pixelorama.png"
    launcher pixelorama <<EOF
exec godot --path "$_d" "\$@"
EOF
    desktop_entry pixelorama Pixelorama pixelorama pixelorama "Graphics;2DGraphics;RasterGraphics;" \
        "Draw pixel art and animate sprites"
}
pixelorama_bdeps() { echo ""; }
pixelorama_rdeps() { echo "godot@testing"; }
pixelorama_needs() { echo ""; }
pixelorama_source() { echo "github Orama-Interactive/Pixelorama"; }

# ---- playbooks/Games/pychess.sh
# THE PYTHON PROGRAMS keep their modules in a directory of their own,
# $PREFIX/lib/copal-store/NAME, and their launcher puts it on PYTHONPATH.
# Not site-packages: Alpine's Python does not read /usr/local's, and a path
# with python3.14 in it breaks the day Alpine moves to 3.15. Every library
# they import comes from Alpine's py3-* packages -- nothing from PyPI.

# PyChess runs from its source tree, the way its README runs it.
PYCHESS_VER=1.2.0
pychess_install() {
    _s=$(gh_source pychess/pychess "$PYCHESS_VER" \
         da989acb45ebe77fa013ab68a5e6d4202c8d831af68e3533c8b96a9b5e387548) || return 1
    _d="$PREFIX/lib/copal-store/pychess"
    mkdir -p "$DEST$_d" "$DEST$PREFIX/share/icons/hicolor/scalable/apps"
    # The whole tree: it opens ARTISTS, AUTHORS and the rest by path at start.
    cp -r "$_s/." "$DEST$_d/"
    rm -rf "$DEST$_d/testing" "$DEST$_d/debian" "$DEST$_d/macos" "$DEST$_d/devsvg"
    cp "$_s/pychess.svg" "$DEST$PREFIX/share/icons/hicolor/scalable/apps/"
    launcher pychess <<EOF
exec python3 "$_d/pychess" "\$@"
EOF
    desktop_entry pychess PyChess pychess pychess "Game;BoardGame;" "Play chess against the computer or online"
}
# Two dialogs on the first start, both spared: the tip of the day, and one
# asking leave to download scoutfish and chess_db -- prebuilt glibc programs,
# which would not run here if they were fetched.
pychess_post() {
    seed_homes .config/pychess/config <<'EOF'
[General]
show_tip_at_startup = False
download_scoutfish = False
download_chess_db = False
dont_show_externals_at_startup = True
EOF
}
pychess_bdeps() { echo ""; }
pychess_rdeps() { echo "python3 py3-gobject3 py3-cairo py3-psutil py3-pexpect py3-sqlalchemy py3-websockets gtk+3.0 gtksourceview4 gstreamer gst-plugins-base gst-plugins-good librsvg stockfish@testing"; }
pychess_needs() { echo ""; }
pychess_source() { echo "github pychess/pychess"; }

# ---- playbooks/System/smc.sh
# System Monitoring Center: GTK4 and libadwaita, meson. It keeps its modules
# in share/, not in a Python library directory, so needs no launcher.
SMC_VER=3.4.1
smc_install() {
    _s=$(gh_source hakandundar34coding/system-monitoring-center "v$SMC_VER" \
         abe601aaa8f6a3beea2874292931d8b0bf43ecb17a75f605feb8b4b08b4708e5) || return 1
    # Its modules go to share/system-monitoring-center, and the script meson
    # writes puts that directory on sys.path itself.
    meson setup "$W/build" "$_s" --prefix="$PREFIX"
    meson compile -C "$W/build"
    DESTDIR="$DEST" meson install -C "$W/build"
}
smc_bdeps() { echo "meson samurai gettext"; }
smc_rdeps() { echo "python3 python3-tkinter py3-gobject3 py3-cairo gtk4.0 libadwaita dmidecode util-linux-misc"; }
smc_needs() { echo ""; }
smc_source() { echo "github hakandundar34coding/system-monitoring-center"; }

# ---- playbooks/Games/taisei.sh
# Taisei: a Touhou fan game, a bullet-hell shooter in C over SDL3, meson. The
# release archive is the one to build from: it carries the submodules that
# GitHub's tag archive leaves out. Its fallbacks are .wrap files that meson
# would download, so downloads are off and every library is Alpine's. Only
# the OpenGL 3.3 renderer is built: the SDL_GPU and GLES ones need shaders
# cross-compiled by glslang and SPIRV-Cross at build time, and GL 3.3 is what
# the Pi's V3D and the VM's virgl both offer. The allocator is musl's own;
# mimalloc would be a subproject. The game's assets are installed as files,
# not packed into zips: the packer compresses with Python's zstd module,
# which Alpine's Python 3.14 is built without. Its threads get glibc-sized
# stacks, as Naev's do (see there).
TAISEI_VER=1.4.6
taisei_install() {
    _t=$(gh_asset taisei-project/taisei "v$TAISEI_VER" "taisei-$TAISEI_VER.tar.xz" \
         18d03c67dcc8c7faff22e8defdafc3a734b46c591618d1a678e6e914846889d9) || return 1
    tar -xJf "$_t" -C "$W" || { warn "$_t did not unpack"; return 1; }
    _s="$W/taisei-$TAISEI_VER"
    LDFLAGS="${LDFLAGS:-} -Wl,-z,stack-size=8388608" \
    meson setup "$W/build" "$_s" --prefix="$PREFIX" --buildtype=release --wrap-mode=nodownload \
        -Dallocator=libc -Dpackage_data=disabled -Dr_default=gl33 -Dr_gles30=disabled -Dr_sdlgpu=disabled \
        -Dshader_transpiler=disabled -Ddocs=disabled -Dtests=disabled -Dgamemode=disabled
    meson compile -C "$W/build" -j "$JOBS"
    DESTDIR="$DEST" meson install -C "$W/build"
}
taisei_bdeps() { echo "build-base meson samurai pkgconf sdl3-dev freetype-dev libwebp-dev zlib-dev zstd-dev cglm-dev libunibreak-dev opusfile-dev libpng-dev openssl-dev"; }
taisei_rdeps() { echo ""; }
taisei_needs() { echo ""; }
taisei_source() { echo "github taisei-project/taisei"; }

# ---- playbooks/Tools/veracrypt.sh
# VeraCrypt: encrypted volumes and whole-disk encryption, TrueCrypt's heir.
# Its own Makefile, wxWidgets for the window, FUSE 3 to present a mounted
# volume. Its Linux 'install' stages into /usr, so the three files that
# matter are placed here instead. Mounting needs root, which it asks for
# through sudo -- on a Copal machine, doas-sudo-shim answers.
VERACRYPT_VER=1.26.29
veracrypt_install() {
    _s=$(gh_source veracrypt/VeraCrypt "VeraCrypt_$VERACRYPT_VER" \
         5141f046e90c8d7660d1eef7d492c4a0ee15283500f092ebb2b72d5260779229) || return 1
    # The Makefile derives SOURCE_DATE_EPOCH from git, or else from the
    # release date in Common/Tcdefs.h with an awk that busybox's awk cannot
    # run; given explicitly, that date is 8 June 2026.
    nice -n 10 make -C "$_s/src" -j "$JOBS" WITHFUSE3=1 SOURCE_DATE_EPOCH=1780876800
    mkdir -p "$DEST$PREFIX/bin" "$DEST$PREFIX/share/applications" "$DEST$PREFIX/share/pixmaps"
    cp "$_s/src/Main/veracrypt" "$DEST$PREFIX/bin/"
    cp "$_s/src/Setup/Linux/veracrypt.desktop" "$DEST$PREFIX/share/applications/"
    cp "$_s/src/Resources/Icons/VeraCrypt-256x256.xpm" "$DEST$PREFIX/share/pixmaps/veracrypt.xpm"
}
veracrypt_bdeps() { echo "build-base pkgconf wxwidgets-dev fuse3-dev pcsc-lite-dev"; }
veracrypt_rdeps() { echo "fuse3 doas-sudo-shim"; }
veracrypt_needs() { echo ""; }
veracrypt_source() { echo "github veracrypt/VeraCrypt"; }

# ---- playbooks/Science/xaos.sh
# XaoS, the real-time fractal zoomer, from its own release. CMake over Qt 6
# Widgets; its OpenGL renderer is an option and stays off, so it draws in
# software and runs the same on every board. Its tutorials and the catalogue
# of formulae are data it installs beside it; its command is 'XaoS'.
XAOS_VER=4.3.8
xaos_install() {
    _s=$(gh_source xaos-project/XaoS "release-$XAOS_VER" \
         509f0b9d8f7f36a8f93613415efac3d55f23c9d108a7a0ca900f2ef7550564cc) || return 1
    cmake_stage "$_s" -DOPENGL=OFF -DMOBILE_UI=OFF || return 1
    # Its menu entry and icon are in xdg/, which the CMake install leaves out,
    # and the entry runs 'xaos' where the binary is 'XaoS'.
    mkdir -p "$DEST$PREFIX/share/applications" "$DEST$PREFIX/share/pixmaps"
    sed 's/^Exec=xaos/Exec=XaoS/' "$_s/xdg/io.github.xaos_project.XaoS.desktop" \
        > "$DEST$PREFIX/share/applications/io.github.xaos_project.XaoS.desktop"
    cp "$_s/xdg/xaos.png" "$DEST$PREFIX/share/pixmaps/xaos.png"
}
xaos_bdeps() { echo "build-base cmake samurai qt6-qtbase-dev qt6-qttools-dev"; }
xaos_rdeps() { echo ""; }
xaos_needs() { echo ""; }
xaos_source() { echo "github xaos-project/XaoS"; }

RECIPES="alephone amiberry ardour astromenace bleachbit browsh ccleste darktable ddnet devilutionx dxx endlesssky ffconverter focuswriter fraqtive funkin kmahjongg konquest kretro kreversi ksnakeduel kspaceduel kubrick librecad naev ohmyposh openshot opentyrian pacman pencil2d persepolis pixelorama pychess smc taisei veracrypt xaos"

# The ~/code projects: cloned and built by copal-build, as the person.
ascitty_bdeps() { echo "git rust cargo"; }
ascitty_rdeps() { echo ""; }
ascitty_source() { echo "clone https://github.com/vonglurt/ascitty.git"; }
birdshot_bdeps() { echo "git build-base cmake samurai pkgconf qt6-qtbase-dev"; }
birdshot_rdeps() { echo ""; }
birdshot_source() { echo "clone https://github.com/vonglurt/birdshot.git"; }
codexofconquest_bdeps() { echo "git nodejs npm"; }
codexofconquest_rdeps() { echo "nodejs"; }
codexofconquest_source() { echo "clone https://github.com/vonglurt/codexofconquest.git"; }
copal_tm_bdeps() { echo "git rust cargo"; }
copal_tm_rdeps() { echo ""; }
copal_tm_source() { echo "clone https://github.com/vonglurt/copal-tm.git"; }
gonex_bdeps() { echo "git go build-base pkgconf make cmake alsa-lib-dev libx11-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev libxxf86vm-dev mesa-dev glu-dev"; }
gonex_rdeps() { echo ""; }
gonex_source() { echo "clone https://github.com/yodacon/gonex.git"; }
orrery_bdeps() { echo "git rust cargo"; }
orrery_rdeps() { echo ""; }
orrery_source() { echo "clone https://github.com/vonglurt/orrery.git"; }
radbeeper_bdeps() { echo "git rust cargo"; }
radbeeper_rdeps() { echo ""; }
radbeeper_source() { echo "clone https://github.com/vonglurt/radbeeper.git"; }
staticstream_bdeps() { echo "git rust cargo"; }
staticstream_rdeps() { echo ""; }
staticstream_source() { echo "clone https://github.com/vonglurt/staticstream.git"; }
urfinkel_bdeps() { echo "git"; }
urfinkel_rdeps() { echo "vice@testing"; }
urfinkel_source() { echo "clone https://github.com/vonglurt/urfinkel.git"; }
yodacon_bdeps() { echo "git go build-base pkgconf make cmake alsa-lib-dev libx11-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev libxxf86vm-dev mesa-dev glu-dev"; }
yodacon_rdeps() { echo ""; }
yodacon_source() { echo "clone https://github.com/yodacon/yodacon.git"; }
CLONES="ascitty birdshot codexofconquest copal-tm gonex orrery radbeeper staticstream urfinkel yodacon"

# The bundles: named lists of program ids (playbooks/bundles/NAME.list).
store_bundle() {
    case "$1" in
        full-monty) echo "taisei naev darktable focuswriter pencil2d ardour9 k3b czkawka_gui fdupes jdupes rdfind xsane skanlite" ;;
        starter) echo "openshot-qt fastfetch btop keepassxc endless-sky" ;;
        *) return 1 ;;
    esac
}
store_bundles() { echo "full-monty starter"; }

# The catalogue programs' postconfiguration, the same bodies stage 12 runs.
# ---- playbooks/Mail/claws-mail.sh
# Claws Mail skips its wizard when accountrc exists. protocol 3 is
# IMAP4, ssl_* 1 is TLS on connect, and the IMAP folder tree is
# declared in folderlist.xml or the account has nowhere to appear.
# Only when answers.txt names a mail address.
claws_mail_post() {
    [ -n "${PI_MAIL_ADDRESS:-}" ] || return 0
    _mname="${PI_MAIL_NAME:-${PI_GIT_NAME:-$PI_MAIL_ADDRESS}}"
    _imap="${PI_MAIL_IMAP:-imap.${PI_MAIL_ADDRESS#*@}}"
    _smtp="${PI_MAIL_SMTP:-smtp.${PI_MAIL_ADDRESS#*@}}"
    cat > "$_t" <<CLAWS
[Account: 1]
account_name=$PI_MAIL_ADDRESS
is_default=1
name=$_mname
address=$PI_MAIL_ADDRESS
protocol=3
receive_server=$_imap
smtp_server=$_smtp
user_id=$PI_MAIL_ADDRESS
password=
use_mail_command=0
ssl_imap=1
ssl_smtp=1
use_smtp_auth=1
smtp_user_id=$PI_MAIL_ADDRESS
set_imapport=1
imap_port=993
set_smtpport=1
smtp_port=465
imap_directory=
imap_subsonly=1
CLAWS
    seed_home_if_absent .claws-mail/accountrc "$_t"
    cat > "$_t" <<FOLD
<?xml version="1.0" encoding="UTF-8"?>
<folderlist>
  <folder type="imap" name="$PI_MAIL_ADDRESS" path="imapcache/$_imap/$PI_MAIL_ADDRESS" account_id="1" />
  <folder type="mh" name="Mail" path="Mail" />
</folderlist>
FOLD
    seed_home_if_absent .claws-mail/folderlist.xml "$_t"
}
# ---- playbooks/Internet/firefox-esr.sh
# Firefox ESR: no welcome tab, no "make me the default", no telemetry.
# A policies file in the distribution directory; read on every start.
firefox_esr_post() {
    if [ -d /usr/lib/firefox-esr ] && [ ! -f /usr/lib/firefox-esr/distribution/policies.json ]; then
        mkdir -p /usr/lib/firefox-esr/distribution
        cat > /usr/lib/firefox-esr/distribution/policies.json <<'POL'
{ "policies": {
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "DisableTelemetry": true,
    "DontCheckDefaultBrowser": true,
    "NoDefaultBookmarks": true } }
POL
        note "/usr/lib/firefox-esr/distribution/policies.json"
    fi
}
# ---- playbooks/Editors/kate.sh
# Kate: its welcome view in every new window. Only when copal has not
# already written a katerc (stage 7 does, with the LSP client); then the
# line is added there instead.
kate_post() {
    printf '[General]\nShow welcome view for new window=false\n' > "$_t"
    seed_home_if_absent .config/katerc "$_t"
}
# ---- playbooks/Internet/qbittorrent.sh
# qBittorrent: the "Legal Notice" box on first start (verified), and no
# vanishing into the tray: on i3 the bar has no tray, so a window closed
# "to the tray" is simply gone until the process is killed.
qbittorrent_post() {
    printf '[LegalNotice]\nAccepted=true\n\n[Preferences]\nGeneral\\CloseToTray=false\nGeneral\\MinimizeToTray=false\nGeneral\\SystrayEnabled=false\n' > "$_t"
    seed_home_if_absent .config/qBittorrent/qBittorrent.conf "$_t"
}
# ---- playbooks/Mail/thunderbird.sh
# Thunderbird: an account is nothing but prefs. profiles.ini names a
# profile, user.js inside it declares IMAP (993, TLS), SMTP (465, TLS)
# and a Local Folders store; the first start opens on the Inbox and
# asks for the password once. The numeric codes are Thunderbird's:
# socketType 3 = SSL/TLS, authMethod 3 = normal password. Only when
# answers.txt names a mail address; otherwise it keeps its wizard.
thunderbird_post() {
    [ -n "${PI_MAIL_ADDRESS:-}" ] || return 0
    _mname="${PI_MAIL_NAME:-${PI_GIT_NAME:-$PI_MAIL_ADDRESS}}"
    _imap="${PI_MAIL_IMAP:-imap.${PI_MAIL_ADDRESS#*@}}"
    _smtp="${PI_MAIL_SMTP:-smtp.${PI_MAIL_ADDRESS#*@}}"
    printf '[General]\nStartWithLastProfile=1\nVersion=2\n\n[Profile0]\nName=default\nIsRelative=1\nPath=copal.default\nDefault=1\n' > "$_t"
    seed_home_if_absent .thunderbird/profiles.ini "$_t"
    cat > "$_t" <<TB
user_pref("mail.accountmanager.accounts", "account1,account2");
user_pref("mail.accountmanager.defaultaccount", "account1");
user_pref("mail.accountmanager.localfoldersserver", "server2");
user_pref("mail.account.account1.identities", "id1");
user_pref("mail.account.account1.server", "server1");
user_pref("mail.account.account2.server", "server2");
user_pref("mail.server.server1.type", "imap");
user_pref("mail.server.server1.hostname", "$_imap");
user_pref("mail.server.server1.port", 993);
user_pref("mail.server.server1.socketType", 3);
user_pref("mail.server.server1.authMethod", 3);
user_pref("mail.server.server1.userName", "$PI_MAIL_ADDRESS");
user_pref("mail.server.server1.name", "$PI_MAIL_ADDRESS");
user_pref("mail.server.server2.type", "none");
user_pref("mail.server.server2.hostname", "Local Folders");
user_pref("mail.server.server2.name", "Local Folders");
user_pref("mail.identity.id1.fullName", "$_mname");
user_pref("mail.identity.id1.useremail", "$PI_MAIL_ADDRESS");
user_pref("mail.identity.id1.smtpServer", "smtp1");
user_pref("mail.smtpservers", "smtp1");
user_pref("mail.smtp.defaultserver", "smtp1");
user_pref("mail.smtpserver.smtp1.hostname", "$_smtp");
user_pref("mail.smtpserver.smtp1.port", 465);
user_pref("mail.smtpserver.smtp1.try_ssl", 3);
user_pref("mail.smtpserver.smtp1.authMethod", 3);
user_pref("mail.smtpserver.smtp1.username", "$PI_MAIL_ADDRESS");
user_pref("mail.shell.checkDefaultClient", false);
user_pref("app.donation.eoy.version.viewed", 99);
TB
    seed_home_if_absent .thunderbird/copal.default/user.js "$_t"
}
# ---- playbooks/Notes/zim.sh
# Zim: without a notebook the first window is "Add Notebook". One in
# ~/Notebooks/Notes, registered as the default, and it opens on a page.
zim_post() {
    printf '[NotebookList]\nDefault=~/Notebooks/Notes\n\n[Notebook 1]\nuri=~/Notebooks/Notes\nname=Notes\n' > "$_t"
    seed_home_if_absent .config/zim/notebooks.list "$_t"
    printf '[Notebook]\nversion=0.4\nname=Notes\nhome=Home\n' > "$_t"
    seed_home_if_absent Notebooks/Notes/notebook.zim "$_t"
}
catalogue_post_for() {  # <program id> -- its post, if it has one
    case "$1" in
        claws-mail) claws_mail_post ;;
        firefox-esr) firefox_esr_post ;;
        kate) kate_post ;;
        qbittorrent) qbittorrent_post ;;
        thunderbird) thunderbird_post ;;
        zim) zim_post ;;
        *) return 0 ;;
    esac
}

# The catalogue's graphical programs: id|about|home, for Copal Apps (rows()).
catalogue_abouts() {
    cat <<'CATABOUTS'
FreeCAD|Parametric 3D CAD for real parts and assemblies. Powerful and heavy, with drawings, meshes and simulation.|
abiword|A light word processor that opens and saves Word documents. Enough for letters and reports without an office suite's weight.|
alacritty|A fast terminal drawn by the GPU. Minimal and configured in one file, and it needs OpenGL.|
arandr|Arranges your monitors: drag the screens, set resolutions and save the layout. For the X desktop.|
audacious|A light music player that plays from playlists, in the spirit of Winamp and XMMS. It can even wear a Winamp skin.|
audacity|The audio editor: record, cut, clean and mix sound. Noise removal, effects and every common format.|
badwolf|A minimal browser on the modern WebKit engine, so today's sites work. It is built to be small and private, and starts in a moment.|
baobab|Shows what is filling the disk as a ring chart. Find the big folders and clear space.|
blender|The 3D suite: modelling, animation, rendering and video editing. Very demanding on memory and graphics.|
blueman-manager|The Bluetooth manager: pair headphones, keyboards and phones. Sends files too.|
brave|A Chromium-based browser that blocks ads and trackers by itself. Installed from Flathub, and the full monty's default browser.|
calibre|The ebook library: organise, convert between formats and send books to a reader. It also edits EPUBs and fetches metadata and covers.|
cataclysm-tiles|Cataclysm: Dark Days Ahead, a survival roguelike in a ruined world. Scavenge, build and try to last, drawn in tiles.|
cherrytree|A hierarchical notebook: notes in a tree, with rich text, images and code. Everything is kept in one file you can carry about.|
chocolate-doom|Chocolate Doom plays Doom exactly as it was in 1993. Freedoom comes with it, so there is a game to play at once.|
chromium|The open-source browser Chrome is built on, with every modern web feature. Heavy on memory, and the one to reach for when a site insists.|
claws-mail|A fast, light mail client from the Sylpheed lineage. Copal can set up your account from the installer's answers.|
codeblocks|Code::Blocks, a C and C++ IDE with GDB debugging and breakpoints. Light for an IDE.|
codium|VSCodium, Visual Studio Code built without Microsoft's telemetry. The editor and its extensions, without the tracking.|
cool-retro-term|A terminal that looks like an old CRT, glow and scanlines included. Convincing, and fun.|
cura|Ultimaker's slicer, which turns 3D models into the G-code a printer follows. It carries profiles for common printers, the Creality Ender 3 among them.|
deadbeef|A small, fast audio player for large music libraries. Plays nearly every format, including tracker modules and chiptunes.|
dillo|A tiny, fast web browser that starts in a blink. It renders plain HTML and CSS and runs no JavaScript, which is exactly right for documentation and old sites.|
dosbox|DOSBox Staging, a modern DOS emulator for old games and programs. Mount a folder as a drive and run the DOS classics.|
drawing|A simple paint program for quick sketches and edits. Crop, resize, annotate and save, with nothing to learn.|
emacs|The extensible editor, with Eglot for language servers built in. Run emacs -nw to use it in a terminal.|
evince|GNOME's document viewer for PDF, PostScript, DjVu and comic books. Search, annotations and a sidebar of thumbnails.|
feh|A command-line image viewer that also sets the wallpaper. Slideshows, montages and thumbnails from the terminal.|
filezilla|An FTP and SFTP client in two panes, local and remote. Drag files between them.|
firefox-esr|Mozilla's Firefox on its extended-support branch: security fixes without monthly changes. Copal sets it up with no welcome tab and no telemetry.|
foliate|A handsome ebook reader for EPUB and more. Themes, a book library, and a clean page to read on.|
freeciv-sdl2|Freeciv, the empire-building strategy game in the tradition of Civilization. Found cities, research and conquer, against the computer or online.|
fs-uae|An Amiga emulator focused on games, with a friendly launcher. It needs Kickstart ROMs for most software.|
galculator|A scientific calculator: algebraic or RPN, in decimal, hex, octal or binary. Small and quick.|
geany|A light programmer's editor that is almost an IDE: build and run with a key. Starts instantly and supports dozens of languages.|
gedit|GNOME's text editor: clean, tabbed, with syntax colours and plugins. A good default for anyone new.|
ghex|GNOME's hex editor for binary files. Edit bytes, search and inspect.|
ghostwriter|A distraction-free Markdown editor with a live preview beside the text. Hemingway mode and focus mode keep you writing.|
gimp|The GNU image editor: retouching, compositing and photo editing. Powerful, and it will use every byte of memory it can find.|
gitk|git-gui to stage and commit, and gitk to browse history as a graph. Git's own graphical tools.|
gnome-disks|GNOME's disk utility: format, partition, image and check SMART health. The simple way to prepare a USB stick.|
gnome-mines|Minesweeper, GNOME's clean version of the classic. Clear the field without touching a mine.|
gnome-sudoku|Sudoku puzzles at four difficulties, with hints and pencil marks. Print a page of them if you prefer paper.|
gnote|Quick notes that link to each other like a small wiki. Type a note's title in another note and it becomes a link.|
gnumeric|A fast, accurate spreadsheet that reads Excel files. Its statistics functions are trusted by people who check them.|
gnuradio-companion|GNU Radio Companion: build software radios by wiring blocks together. Design and run signal processing on a live SDR.|
gparted|The partition editor: create, resize, move and copy partitions. Work with any disk that is not in use.|
gpicview|A tiny, fast image viewer. Opens instantly, and flips through a folder with the arrow keys.|
gqrx|An SDR receiver with a waterfall display. Tune in AM, FM and SSB with an RTL-SDR or HackRF.|
gthumb|An image browser and organiser: browse, tag, rotate and lightly edit photos. It imports from cameras too.|
gtkwave|A viewer for digital waveforms from simulations. Open VCD files from Verilog or VHDL.|
guake|A drop-down terminal on F12, for GNOME. It slides down from the top of the screen.|
gzdoom|GZDoom, a modern Doom engine with mouse look and high resolutions. Freedoom is installed with it, so it plays without the original data.|
hydrogen|A drum machine and pattern sequencer. Build beats from sampled kits and chain the patterns into a song.|
inkscape|The professional vector drawing program: logos, diagrams and illustrations. It works in SVG and exports PDF and PNG.|
kate|KDE's advanced text editor with language servers built in, so completion and errors appear as you type. Copal skips its welcome page.|
kdevelop|KDE's IDE for C, C++ and Python, with deep code understanding. Debugging with GDB and breakpoints built in.|
kdiff3|Three-way comparison and merging of files and folders. It resolves merge conflicts line by line.|
kicad|Electronics design: draw the schematic, lay out the circuit board, and export Gerbers for manufacture. The standard free tool.|
kitty|A featureful GPU terminal: tabs, splits, images and ligatures. It needs OpenGL.|
kmail|KDE's mail client, powerful and deeply integrated with the KDE desktop. It brings the Akonadi storage service with it, so it is heavy.|
kompare|KDE's visual diff viewer. Shows the differences between files and applies patches.|
koreader|An ebook reader built for e-ink devices, excellent for PDFs and scanned books. It reflows columns and crops margins so pages fit the screen.|
krename|Batch-renames files by rules: numbering, patterns, dates and tags. Preview every name before anything changes.|
krita|A professional digital painting program, made by artists. Brushes, layers and animation, and it wants a real machine.|
krusader|A powerful two-pane file manager for KDE. Archives, remote connections, synchronising folders and batch renaming.|
ktouch|A typing tutor with a keyboard map on screen. Lessons from home row to full speed.|
lagrange|A beautiful browser for Gemini, the small web. Also reads Gopher and Finger.|
lapce|A modern, fast code editor written in Rust. Language servers, a built-in terminal and remote editing.|
lbreakout2|A breakout game with power-ups, bonus levels and a level editor. Smash every brick with the ball and the paddle.|
libreoffice|LibreOffice Writer, the full office word processor. Opens and saves Word documents with their layout intact, and needs the memory to match.|
libresprite|A pixel-art editor and sprite animator, the free fork of Aseprite. Layers, frames and onion skins for game art.|
liferea|A desktop feed reader for RSS and Atom. Subscribe to sites and read new posts in one window, even offline.|
lmms|A music workstation for making songs from patterns, synthesisers and samples. Free, and in the tracker tradition.|
luanti|Luanti, formerly Minetest, an open voxel sandbox. Build, mine and explore, alone or on servers, with thousands of mods.|
lxterminal|LXDE's terminal: light, with tabs. Starts quickly on small machines.|
lyx|A document processor over LaTeX: write in a document view and get LaTeX typesetting. Ideal for papers and theses with maths.|
meld|Compare files and folders side by side, and merge the differences. Works with git too.|
mgba-qt|mGBA, an accurate Game Boy Advance emulator. It also plays Game Boy and Game Boy Color games.|
milkytracker|A music tracker in the style of Fasttracker II. Compose modules in patterns of notes, as the demo scene did.|
minuet|Music theory and ear training: intervals, chords and scales. Hear them, then name them.|
mousepad|A small, quick text editor for everyday files. Tabs, syntax colours and nothing to configure.|
mpv|A minimal, powerful video and audio player with no interface until you need one. Keyboard-driven, and plays everything.|
mscore|MuseScore, for writing sheet music. Enter notes, hear them played back, and print or export the score.|
mupdf|The fastest PDF viewer there is, and among the smallest. Also reads EPUB and XPS.|
mypaint|A painting program that feels like paper, with an endless canvas. Its brushes respond to a pen's pressure.|
netsurf|A small web browser with its own layout engine, written for slow machines. Pages that do not need JavaScript look right and load quickly.|
nm-applet|The network applet: choose wifi networks and VPNs from the tray. NetworkManager's own.|
nsxiv|A minimal, keyboard-driven image viewer with a thumbnail grid. Scriptable, and quick on large folders.|
openmw-launcher|OpenMW, a modern engine for The Elder Scrolls III: Morrowind. It needs the game's original data files, which it does not include.|
openttd|OpenTTD, the transport tycoon: build railways, roads, ships and airlines. Carry goods between towns and industries, for decades of game time.|
pavucontrol|The volume control for PulseAudio and PipeWire. Set levels for each program and choose the output.|
pcmanfm|A light, fast file manager with tabs. It can also draw the desktop.|
pingus|A puzzle game in the style of Lemmings, with penguins. Give them jobs so the flock reaches the exit safely.|
pinta|A paint program in the style of Paint.NET: layers, effects and unlimited undo. Simpler than GIMP, more capable than Paint.|
pulseview|The sigrok logic analyser and oscilloscope viewer. Capture and decode digital signals from cheap USB analysers.|
qalculate-gtk|A calculator that understands units and currencies. 5 km/h to mph, or a whole equation, typed as you would say it.|
qbittorrent|A full-featured BitTorrent client with search, RSS feeds and scheduling. Copal accepts its legal notice for you and keeps it out of the tray, which the i3 bar lacks.|
qspectrumanalyzer|A spectrum analyser on an SDR dongle. Watch the airwaves across a whole band.|
qsstv|Receives and sends slow-scan television, pictures over ham radio. Also does digital image modes.|
qterminal|A light Qt terminal with tabs, splits and a drop-down mode. From the LXQt desktop.|
remmina|A remote desktop client for RDP, VNC and SSH. Keeps a list of your connections, one click each.|
retroarch|One front end for dozens of console emulators, each a core it loads. Shaders, save states and controller settings work the same for all of them.|
ristretto|Xfce's image viewer: quick, simple, with a thumbnail bar. Good for looking through a folder of photos.|
sakura|A small GTK terminal with tabs. Simple and light.|
schismtracker|A music tracker modelled on Impulse Tracker. The keyboard-driven way to write .it modules.|
scummvm|Plays classic point-and-click adventures: Monkey Island, Day of the Tentacle and hundreds more. Bring the games' data, or try the freeware ones.|
sdrangel|An SDR transceiver for many modes and devices. Powerful and heavy.|
simple-scan|Scanning made simple: press Scan, crop, and save as PDF or an image. Multi-page documents come out as one file.|
sol|AisleRiot, GNOME's collection of more than eighty solitaire games. Klondike, Spider, FreeCell and dozens more.|
solvespace|A parametric 2D and 3D CAD program, tiny and quick. Constrain sketches, extrude parts, and export STL for printing.|
speedcrunch|A fast, high-precision calculator with history. Works in binary, octal and hex too.|
sqlitebrowser|DB Browser for SQLite: open a database, browse its tables and run queries. Edit data without writing SQL.|
st|The suckless terminal: the smallest and quickest there is. Configured by editing its source.|
supertux2|SuperTux, a classic side-scrolling platformer with Tux the penguin. It needs a GPU to run smoothly.|
terminator|A terminal that splits into a grid of panes. Type into several at once.|
thunar|Xfce's file manager: quick and simple, with bulk rename. Plugins add archives and more.|
thunderbird|Mozilla's mail client, with calendars and contacts built in. Copal can set up your account from the installer's answers, so it opens on your inbox.|
tilda|A drop-down terminal that slides down on F1. Light, and always one key away.|
transmission-gtk|A simple BitTorrent client that does its job and stays out of the way. Add a torrent or magnet link and it downloads in the background.|
tuxpaint|A drawing program for children, with sounds, stamps and big buttons. Nothing to break, and a lot to try.|
umbrello6|KDE's UML modeller: class, sequence and activity diagrams. It can also generate code from them.|
urxvt|rxvt-unicode, a light and fast terminal. Copal's default on the X desktop.|
vlc|The media player that plays anything: files, discs and network streams. It converts between formats too.|
vsid|VICE's player for Commodore 64 SID music. Load a tune from the High Voltage SID Collection and hear the C64's sound chip.|
welle-io|A DAB and DAB+ digital radio receiver for SDR dongles. Tune the stations and read their slideshows.|
wesnoth|The Battle for Wesnoth, turn-based fantasy strategy on a hex map. Long campaigns and online play, and it wants a capable machine.|
wezterm|A GPU terminal with a multiplexer built in: tabs, panes and SSH domains. Configured in Lua.|
widelands|A settlers-like economic strategy game. Build a slow, detailed economy of roads and workshops, then defend it.|
wireshark|The network protocol analyser: capture traffic and inspect every packet. It decodes hundreds of protocols.|
x64sc|VICE's Commodore 64 emulator, cycle-exact. Stage 9 sets it up with disk images and launchers.|
xarchiver|A light archive manager for zip, tar, 7z and more. Open an archive, browse it and extract it.|
xboard|XBoard, the classic chess board, with GNU Chess to play against. It also connects to internet chess servers.|
xfburn|A simple disc burner for CDs and DVDs: data, audio and ISO images. Light, from Xfce.|
xfce4-taskmanager|A light task manager: processes, CPU and memory at a glance. End a stuck program with a click.|
xfce4-terminal|Xfce's terminal: tabs, colours, transparency and a drop-down mode. Featureful without being heavy.|
xfe|A two-pane file manager in the style of Norton Commander, with a mouse. Fast on small machines.|
xfig|The classic vector drawing program for diagrams and figures. Old, precise, and tiny.|
xpad|Sticky notes for the desktop. Each note is its own little window, and they come back after a reboot.|
xpdf|The classic PDF viewer for X. Plain and dependable, with a few tools for text and images alongside.|
xscreensaver|Screen locking and a collection of screensavers for X. Hundreds of hacks, from the classic to the absurd.|
xterm|The original X terminal. Always there, and always works.|
yakuake|KDE's drop-down terminal on F12, built on Konsole. Tabs and splits too.|
zathura|A keyboard-driven PDF viewer with vim-style keys. Small, fast, and nothing on screen but the page.|
zim|A desktop wiki: notes as linked pages, saved as plain text files. Copal creates a first notebook so it opens straight onto a page.|
zutty|A very fast X11 terminal drawn with the GPU. Accurate and minimal.|
CATABOUTS
}
# <<< playbooks: recipes

# ------------------------------------------------------------ recipe driver ---

is_recipe() { case " $RECIPES " in *" $1 "*) return 0 ;; esac; return 1; }
is_clone()  { case " $CLONES " in *" $1 "*) return 0 ;; esac; return 1; }

missing_apks() {  # <names...> -- the ones apk's database does not have
    awk -v want="$*" '
        BEGIN { n = split(want, w, " ") }
        /^P:/ { have[substr($0, 3)] = 1 }
        END { for (i = 1; i <= n; i++) { p = w[i]; sub(/@testing$/, "", p); if (!(p in have)) printf "%s ", w[i] } }' "$APKDB"
}

build_recipe() {  # <recipe>
    _r="$1"
    is_recipe "$_r" || die "no recipe called $_r"
    JOBS="${COPAL_STORE_JOBS:-$(nproc 2>/dev/null || echo 1)}"
    W="$WORK/$_r"; DEST="$W/stage"
    mkdir -p "$STATE" "$LOGDIR" "$CACHE" || die "cannot create $STATE, $LOGDIR or $CACHE"
    _log="$LOGDIR/$_r.log"
    say "$_r: built from GitHub source"
    note "log: $_log"

    _b=$("${_r}_bdeps"); _rt=$("${_r}_rdeps")
    if [ "${COPAL_STORE_NODEPS:-0}" = 1 ]; then
        _m=$(missing_apks $_b $_rt)
        [ -z "$_m" ] || note "not installed (expected to be provided some other way): $_m"
    else
        say "Build and run dependencies"
        store_event "$_r" deps start
        case " $_b $_rt " in *@testing*) enable_testing_tag ;; esac
        # Runtime dependencies under a virtual package named for the recipe,
        # so 'remove' can hand them back to apk to drop if nothing else wants
        # them; build-only ones under another, deleted once the build is done.
        # shellcheck disable=SC2086
        [ -z "$_rt" ] || apk add -t "copal-store-$_r" $_rt || { warn "could not install what $_r needs to run"; return 1; }
        # shellcheck disable=SC2086
        # In a batch (install_ids, several recipes) every build dependency is
        # already in place under .copal-store-build-batch.
        [ -z "$_b" ] || [ "${COPAL_STORE_BATCH:-0}" = 1 ] \
            || apk add -t ".copal-store-build-$_r" $_b || { warn "could not install what $_r needs to build"; return 1; }
        store_event "$_r" deps ok
    fi

    if type "${_r}_pre" >/dev/null 2>&1; then
        store_event "$_r" pre start
        "${_r}_pre" || { warn "$_r: its preconfiguration failed"; store_event "$_r" pre failed; return 1; }
        store_event "$_r" pre ok
    fi

    # TMPDIR inside the work tree: a compiler's temporary files, an LTO link's
    # especially, go to disk rather than a small tmpfs /tmp, and leave with
    # the tree.
    rm -rf "$W"; mkdir -p "$DEST" "$W/tmp"
    _t0=$(date +%s)
    store_event "$_r" install start "\"log\":\"$_log\""
    say "Compiling -- 'tail -f $_log' in another terminal to watch"
    # IN A NEW SHELL, not a subshell. A recipe relies on set -e to stop at
    # the first failed step, and a shell ignores set -e in everything to the
    # left of || and inside an if -- subshells included, however deep, and
    # build_recipe is itself called as 'build_recipe ... || _rc=1'. Seen on
    # the bench: cmake failed, and the recipe carried on and installed a
    # launcher for a binary that was never built. A fresh 'sh' starts with
    # set -e in force.
    W="$W" DEST="$DEST" JOBS="$JOBS" PREFIX="$PREFIX" CACHE="$CACHE" TMPDIR="$W/tmp" \
        sh "$0" __build "$_r" > "$_log" 2>&1
    if [ $? -ne 0 ]; then
        warn "$_r did not build. The last lines of $_log:"
        tail -n 20 "$_log" | sed 's/^/      /' >&2
        store_summary "$_r" failed "$(( $(date +%s) - _t0 ))"
        store_event "$_r" install failed "\"secs\":$(( $(date +%s) - _t0 ))"
        # The tree goes, the record stays: the summary has the failure and
        # the compressed log has the whole of it. Keep it to look inside.
        if [ "${COPAL_STORE_KEEP_WORK:-0}" = 1 ]; then
            note "the build tree is kept in $W; the system is unchanged"
        else
            rm -rf "$W"
            note "the system is unchanged; the full log is $_log.gz (COPAL_STORE_KEEP_WORK=1 keeps the build tree)"
        fi
        drop_build_deps "$_r"
        return 1
    fi
    _secs=$(( $(date +%s) - _t0 ))
    note "built in $_secs s"
    store_event "$_r" install ok "\"secs\":$_secs"

    # WHAT IT LINKS AGAINST, asked of the binaries rather than written down.
    # Every NEEDED library of every ELF file staged, less the ones the recipe
    # installs itself, becomes an apk 'so:' dependency of copal-store-NAME --
    # abuild's own method. A hand-kept list misses things and goes stale:
    # Boost's runtime package is boost1.84-filesystem, a new name every
    # Alpine release, while so:libboost_filesystem.so.1.84.0 is whatever
    # this machine's Boost actually is. NAME_rdeps is left for what no ELF
    # header can say: Python modules, data, programs run by name.
    _sos=$(needed_sonames "$DEST")
    if [ "${COPAL_STORE_NODEPS:-0}" = 1 ]; then
        _lost=$(for _so in $_sos; do
                    for _dir in /lib /usr/lib $(printf '%s' "${LD_LIBRARY_PATH:-}" | tr ':' ' '); do
                        [ -e "$_dir/$_so" ] && continue 2
                    done; printf '%s ' "$_so"; done)
        [ -z "$_lost" ] || warn "libraries it needs that this machine cannot find: $_lost"
    elif [ -n "$_sos" ]; then
        # shellcheck disable=SC2046,SC2086
        apk add -q -t "copal-store-$_r" $_rt $(printf 'so:%s ' $_sos) \
            || warn "could not record the libraries $_r needs; 'apk del' may take them from it"
    fi

    # Everything a recipe installs goes under $PREFIX; that is what makes the
    # file list the whole truth, and 'remove' complete.
    _out=$(cd "$DEST" && find . ! -type d | sed 's|^\.||' | grep -v "^$PREFIX/" | head -n 5)
    if [ -n "$_out" ]; then
        warn "$_r staged files outside $PREFIX -- a recipe bug, nothing installed:"
        printf '%s\n' "$_out" | sed 's/^/      /' >&2
        drop_build_deps "$_r"; return 1
    fi

    # Refuse to write over a file this recipe did not put there last time --
    # the same caution flathub_shim takes with a binary apk owns.
    _new="$W/files"; (cd "$DEST" && find . ! -type d | sed 's|^\.||' | sort) > "$_new"
    _old="$STATE/$_r.files"; [ -f "$_old" ] || : > "$_old.none"
    _clash=$(while IFS= read -r _f; do
                 [ -e "$_f" ] || [ -L "$_f" ] || continue
                 grep -qxF "$_f" "$_old" 2>/dev/null || printf '%s\n' "$_f"
             done < "$_new")
    rm -f "$_old.none"
    if [ -n "$_clash" ] && [ "${COPAL_STORE_FORCE:-0}" != 1 ]; then
        warn "$_r would overwrite files it does not own:"
        printf '%s\n' "$_clash" | head -n 10 | sed 's/^/      /' >&2
        note "nothing was installed. COPAL_STORE_FORCE=1 overrides this."
        drop_build_deps "$_r"; return 1
    fi

    # An upgrade: the old build's files go first, all of them -- they are
    # this recipe's own by the check above, and a file installed read-only
    # (meson installs scripts 0555) cannot be copied over by a non-root
    # bench, which is how this was found.
    if [ -f "$_old" ]; then
        while IFS= read -r _f; do rm -f "$_f"; done < "$_old"
    fi
    cp -a "$DEST$PREFIX/." "$PREFIX/" || { warn "copying $_r into place failed"; return 1; }
    cp "$_new" "$_old"
    (cd "$DEST" && find . -mindepth 1 -type d | sed 's|^\.||' | sort -r) > "$STATE/$_r.dirs"

    if type "${_r}_post" >/dev/null 2>&1; then
        store_event "$_r" post start
        if "${_r}_post"; then store_event "$_r" post ok; else store_event "$_r" post failed; fi
    fi
    have update-desktop-database && update-desktop-database -q "$PREFIX/share/applications" 2>/dev/null
    store_summary "$_r" ok "$_secs"
    rm -rf "$W"
    drop_build_deps "$_r"
    note "installed: $(wc -l < "$_old") files under $PREFIX -- 'copal-store summary' for the record"
}

# Is it on the machine? Its command resolves, or, for a font (no command),
# its first package is installed.
installed_id() {  # <bin> <install field>
    if [ "$1" != "-" ]; then have "$1"
    else case "$2" in
        *@clone) [ -d "$HOME/code/${2%@clone}" ] ;;    # a checkout with no command of its own
        *)       apk info -e "${2%%[@ ]*}" >/dev/null 2>&1 ;;
    esac; fi
}

# Every row with its status last, for a window to read: the rows() fields
# (id|shelf|label|install|bin|mode|about|home|origin) and installed|available.
rows_status() {
    rows | while IFS='|' read -r _id _sec _label _inst _bin _mode _desc _home _orig; do
        if installed_id "$_bin" "$_inst"; then _st=installed; else _st=available; fi
        printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$_id" "$_sec" "$_label" "$_inst" "$_bin" "$_mode" "$_desc" "$_home" "$_orig" "$_st"
    done
}

# ONE PROGRAM, IN FULL: what Copal Apps shows beside the list -- what it is,
# where it comes from, what it needs, the steps its playbook takes, whether
# it is installed, and what its last build recorded.
playbook_show() {  # <id>
    _row=$(row_for "$1"); [ -n "$_row" ] || die "nothing called '$1'"
    IFS='|' read -r _id _sec _label _inst _bin _mode _desc _home _orig <<EOF
$_row
EOF
    if installed_id "$_bin" "$_inst"; then _st=installed; else _st=available; fi
    printf '%s  [%s]\n' "$_label" "$_st"
    printf '  %-10s %s\n' id "$_id" shelf "$_sec"
    [ -z "$_desc" ] || printf '  %-10s %s\n' about "$_desc"
    [ -z "$_home" ] || printf '  %-10s %s\n' home "$_home"
    _steps=""
    for _p in $_inst; do
        case "$_p" in
            *@source)
                _r=${_p%@source}
                printf '  %-10s %s\n' playbook "$_r" source "$("${_r}_source")"
                printf '  %-10s %s\n' build "$("${_r}_bdeps")" runs "$("${_r}_rdeps")"
                [ -z "$("${_r}_needs")" ] || printf '  %-10s %s\n' needs "$("${_r}_needs")"
                _steps="deps"
                for _f in pre install post; do type "${_r}_$_f" >/dev/null 2>&1 && _steps="$_steps, $_f"; done
                ;;
            *@clone)
                _f=$(printf '%s' "${_p%@clone}" | tr -- '-.+' '___')
                printf '  %-10s %s\n' playbook "${_p%@clone}" source "$("${_f}_source")"
                printf '  %-10s %s\n' build "$("${_f}_bdeps")" runs "$("${_f}_rdeps")"
                _steps="${_steps:+$_steps, }deps, clone into ~/code, copal-build ${_p%@clone}" ;;
            *@flathub) _steps="${_steps:+$_steps, }flatpak install ${_p%@flathub}" ;;
            *)  _steps="${_steps:+$_steps, }apk add $_p" ;;
        esac
    done
    printf '  %-10s %s\n' steps "$_steps" origin "$_orig"
    for _p in $_inst; do
        case "$_p" in *@source) ;; *) continue ;; esac
        _last=$(awk -v r="${_p%@source}" '$1 == "==" { on = ($2 == r) } on' "$LOGDIR/summary.txt" 2>/dev/null \
                | awk '/^== /{b=""} {b = b $0 "\n"} END {printf "%s", b}')
        [ -z "$_last" ] || { printf '  last build\n'; printf '%s' "$_last" | sed 's/^/    /'; }
    done
}

# A CATALOGUE PROGRAM'S POST, when Copal Apps installs it: the same step
# stage 12 runs (catalogue_post_for, from its playbook). It reads the
# installer's answers from /boot/copal.conf -- the mail account, which
# stage 1 wrote there, values already cleaned -- and seeds every home that
# lacks the file, never one that has it.
seed_home_if_absent() {  # <relative path> <source file> -- the installer's name for seed_homes
    seed_homes "$1" < "$2"
}
catalogue_post() {  # <program id>
    [ "$(id -u)" = 0 ] || return 0            # seeding homes is root's; a bench has no post
    # shellcheck disable=SC1091
    [ -r /boot/copal.conf ] && . /boot/copal.conf
    W="${W:-$(mktemp -d)}"; _t=$(mktemp); _rcp=0
    store_event "$1" post start
    catalogue_post_for "$1" || _rcp=1
    rm -f "$_t"
    if [ $_rcp = 0 ]; then store_event "$1" post ok; else store_event "$1" post failed; fi
    return $_rcp
}

# ONE EVENT: <playbook or id> <step> <state> [extra JSON members]. Steps are
# run, program, deps, pre, install, post; states start, ok, failed. Never
# fatal: a progress view that cannot be written to is not a failed install.
store_event() {
    mkdir -p "${EVENTS%/*}" 2>/dev/null
    # "program" is the id being installed -- a playbook with several
    # programs, or one named apart from its command, is still one thread.
    printf '{"t":%s,"playbook":"%s","program":"%s","step":"%s","state":"%s"%s}\n' \
        "$(date +%s)" "$1" "${COPAL_PROGRAM:-$1}" "$2" "$3" "${4:+,$4}" >> "$EVENTS" 2>/dev/null || true
}

# A ~/CODE PROJECT: cloned into ~/code and built by copal-build, as the person
# who asked -- never as root, since a checkout is somebody's working tree.
# Its build and run dependencies are installed first (or were, in a batch);
# its URL joins copal-code's list, so 'copal-code' keeps it current; a
# checkout already there is left exactly as it is and only built.
clone_recipe() {  # <name>
    _r="$1"; _f=$(printf '%s' "$_r" | tr -- '-.+' '___')
    _url=$("${_f}_source"); _url=${_url#clone }
    _u="${DOAS_USER:-${SUDO_USER:-$(id -un)}}"
    if [ "$_u" = root ]; then
        warn "$_r is a checkout, and a checkout belongs to a person: run 'doas copal-store install $_r' from your own account"
        return 1
    fi
    mkdir -p "$STATE" "$LOGDIR" || die "cannot create $STATE or $LOGDIR"
    _log="$LOGDIR/$_r.log"
    say "$_r: cloned into ~$_u/code and built there"
    _b=$("${_f}_bdeps"); _rt=$("${_f}_rdeps")
    if [ "${COPAL_STORE_NODEPS:-0}" != 1 ]; then
        store_event "$_r" deps start
        case " $_b $_rt " in *@testing*) enable_testing_tag ;; esac
        # shellcheck disable=SC2086
        [ -z "$_rt" ] || apk add -t "copal-store-$_r" $_rt || { warn "could not install what $_r needs to run"; return 1; }
        # shellcheck disable=SC2086
        [ -z "$_b" ] || [ "${COPAL_STORE_BATCH:-0}" = 1 ] \
            || apk add -t ".copal-store-build-$_r" $_b || { warn "could not install what $_r needs to build"; return 1; }
        store_event "$_r" deps ok
    fi
    have copal-code && [ "$(id -u)" = 0 ] && copal-code add "$_url" >/dev/null 2>&1 || true
    _t0=$(date +%s)
    store_event "$_r" install start "\"log\":\"$_log\""
    say "Cloning and building -- 'tail -f $_log' in another terminal to watch"
    _cmd="PATH=/usr/local/bin:\$HOME/.local/bin:\$PATH; mkdir -p \$HOME/code && cd \$HOME/code \
          && { [ -d '$_r' ] || git clone --recurse-submodules '$_url' '$_r'; } \
          && if command -v copal-build >/dev/null 2>&1; then copal-build '$_r'; \
             else echo 'copal-build is not here: cloned, not built'; fi"
    if [ "$(id -u)" = 0 ]; then su - "$_u" -c "$_cmd" > "$_log" 2>&1; else sh -c "$_cmd" > "$_log" 2>&1; fi
    _rc=$?; _secs=$(( $(date +%s) - _t0 ))
    W="$WORK/$_r"; DEST="$W/stage"; mkdir -p "$W"
    printf '%s -> ~%s/code/%s\n' "$_url" "$_u" "$_r" > "$W/.sources"   # the summary's source line
    if [ $_rc -ne 0 ]; then
        warn "$_r did not clone or build. The last lines of $_log:"
        tail -n 20 "$_log" | sed 's/^/      /' >&2
        store_summary "$_r" failed "$_secs"; store_event "$_r" install failed "\"secs\":$_secs"
        rm -rf "$W"; drop_build_deps "$_r"; return 1
    fi
    note "cloned and built in $_secs s"
    store_event "$_r" install ok "\"secs\":$_secs"
    store_summary "$_r" ok "$_secs"
    rm -rf "$W"; drop_build_deps "$_r"
}

# THE INSTALL SUMMARY. One entry per build in $LOGDIR/summary.txt: the
# result and time, what was installed and how large, the source files kept
# in the cache, the optional features the build said it could not find, and
# for a failure the last lines of its log. The full log is compressed beside
# it as NAME.log.gz. Test frameworks and documentation tools are left out of
# the absences: they are never wanted on the machine.
#
# And the other side of it, "with": what the build found and compiled in --
# CMake's feature summary and its Found lines, Meson's dependencies. For an
# editor or a player that is the answer to "which formats, which codecs":
# OpenEXR, libheif, JPEG XL, FFmpeg, Lua... as this build has them.
# The features a build log says were found, as one comma list: CMake's
# FeatureSummary ("* Name, description" under "have been enabled"), its
# "-- Found Name:" lines, and Meson's "Run-time dependency name found: YES".
# The plumbing everything has -- threads, pkg-config, git -- is not news.
store_with() {  # <log>
    _e=$(printf '\033')
    sed "s/${_e}\[[0-9;]*[mK]//g" "$1" 2>/dev/null | awk '
        /features have been enabled:/ { on = 1; next }
        /features have been disabled:|following (OPTIONAL|REQUIRED)/ { on = 0 }
        on && /^ \* / { sub(/^ \* /, ""); sub(/,.*/, ""); print; next }
        /^-- Found [A-Za-z]/ { n = $3; sub(/:.*/, "", n); print n; next }
        /[Dd]ependency .* found: YES/ { for (i = 1; i < NF; i++) if ($i == "dependency") { print $(i + 1); break } }
    ' | grep -v -i -E '^(threads|pkgconfig|pkg-config|git|python3?|perl|intl|m|dl|rt)$' \
      | awk '!seen[tolower($0)]++' | head -n 40 | paste -sd, - | sed 's/,/, /g'
}

store_summary() {  # <recipe> <ok|failed> <seconds>
    _lg="$LOGDIR/$1.log"; _e=$(printf '\033')
    {
        printf '\n== %s  %s  %s in %s s\n' "$1" "$(date '+%Y-%m-%d %H:%M')" "$2" "$3"
        # A staged build has its file list; a clone (built into ~/.local/bin by
        # copal-build) has none. Tested, not redirected: busybox runs wc as a
        # builtin, and a failed redirection there ends the whole script.
        if [ "$2" = ok ] && [ -f "$W/files" ]; then
            printf '   installed  %s files, %s MB under %s\n' "$(wc -l < "$W/files")" \
                "$(( $(du -sk "$DEST$PREFIX" 2>/dev/null | cut -f1) / 1024 ))" "$PREFIX"
        fi
        [ -s "$W/.sources" ] && sort -u "$W/.sources" | sed 's/^/   source     /; s/$/  (kept)/'
        printf '   log        %s.gz\n' "$_lg"
        sed "s/${_e}\[[0-9;]*[mK]//g" "$_lg" 2>/dev/null \
            | grep -E 'Not found: |Could NOT find [A-Za-z]|^-- .*[Nn]ot found *$' \
            | grep -v -i -E 'looking for|gtest|catch2|cppunit|doxygen|ruby|sphinx|po4a|luacheck' \
            | sed 's/^[- ]*//' | sort -u | head -n 8 | sed 's/^/   absent     /'
        store_with "$_lg" | fold -s -w 64 | sed '1s/^/   with       /; 2,$s/^/              /'
        [ "$2" = ok ] || tail -n 15 "$_lg" | sed "s/${_e}\[[0-9;]*[mK]//g; s/^/   | /"
    } >> "$LOGDIR/summary.txt" 2>/dev/null
    gzip -9 -f "$_lg" 2>/dev/null || true
}

needed_sonames() {  # <staging dir> -- NEEDED libraries not provided by the stage itself
    find "$1" -type f | while IFS= read -r _f; do
        readelf -d "$_f" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'
    done | sort -u > "$W/needed"
    find "$1" -name '*.so*' | sed 's|.*/||' | sort -u > "$W/own"
    comm -23 "$W/needed" "$W/own" | tr '\n' ' '
}

drop_build_deps() {
    [ "${COPAL_STORE_NODEPS:-0}" = 1 ] && return 0
    [ "${COPAL_STORE_BATCH:-0}" = 1 ] && return 0
    [ "${COPAL_STORE_KEEP_BUILD_DEPS:-0}" = 1 ] && return 0
    apk del -q ".copal-store-build-$1" >/dev/null 2>&1 || true
}

remove_recipe() {  # <recipe>
    _f="$STATE/$1.files"
    [ -f "$_f" ] || { warn "$1 was not installed by copal-store"; return 1; }
    while IFS= read -r _p; do rm -f "$_p"; done < "$_f"
    [ -f "$STATE/$1.dirs" ] && while IFS= read -r _d; do rmdir "$_d" 2>/dev/null; done < "$STATE/$1.dirs"
    rm -f "$_f" "$STATE/$1.dirs"
    [ "${COPAL_STORE_NODEPS:-0}" = 1 ] || apk del -q "copal-store-$1" >/dev/null 2>&1 || true
    note "removed $1"
}

# ------------------------------------------------------------ verbs ---
install_ids() {
    _rc=0
    # PREREQUISITES FIRST, for a batch. With more than one recipe named, the
    # build and run dependencies of all of them go in with one apk call before
    # any compiling starts, and come out with one after: the full monty's
    # recipes share most of a Qt, an SDL and a GTK, and installing and
    # removing those for each program in turn costs more than the builds.
    _recs=""
    for _id in "$@"; do
        for _p in $(row_for "$_id" | cut -d'|' -f4); do
            case "$_p" in *@source) _recs="$_recs ${_p%@source}" ;; *@clone) _recs="$_recs ${_p%@clone}" ;; esac
        done
    done
    _batch=0
    if [ "$(echo $_recs | wc -w)" -gt 1 ] && [ "${COPAL_STORE_NODEPS:-0}" != 1 ]; then
        _all=$(for _r in $_recs; do _f=$(printf '%s' "$_r" | tr -- '-.+' '___')
                   { is_recipe "$_r" || is_clone "$_r"; } && { "${_f}_bdeps"; "${_f}_rdeps"; }; done | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')
        say "Build prerequisites for$_recs, installed once"
        case " $_all " in *@testing*) enable_testing_tag ;; esac
        # shellcheck disable=SC2086
        if apk add -t .copal-store-build-batch $_all; then
            _batch=1; export COPAL_STORE_BATCH=1
        else
            warn "the combined set did not install -- each program installs its own instead"
        fi
    fi
    _of=$#; _n=0
    store_event run run start "\"of\":$_of,\"ids\":\"$*\""
    for _id in "$@"; do
        _n=$((_n + 1))
        _row=$(row_for "$_id"); [ -n "$_row" ] || { warn "nothing called '$_id'"; _rc=1; continue; }
        _inst=$(printf '%s' "$_row" | cut -d'|' -f4)
        _label=$(printf '%s' "$_row" | cut -d'|' -f3)
        _prc=$_rc; _rc=0; COPAL_PROGRAM=$_id
        store_event "$_id" program start "\"n\":$_n,\"of\":$_of,\"label\":\"$(printf '%s' "$_label" | tr -d '"')\""
        say "Installing $_label"
        _apks=""; _flat=""
        for _p in $_inst; do
            case "$_p" in
                *@source)  build_recipe "${_p%@source}" || _rc=1 ;;
                *@clone)   clone_recipe "${_p%@clone}" || _rc=1 ;;
                *@flathub) _flat="$_flat $_p" ;;
                *)         _apks="$_apks $_p" ;;
            esac
        done
        # shellcheck disable=SC2086
        if [ -n "$_apks" ]; then
            if apk_install $_apks; then
                # A catalogue program is finished by its playbook's post.
                case "$(printf '%s' "$_row" | cut -d'|' -f9)" in catalogue) catalogue_post "$_id" || _rc=1 ;; esac
                # A terminal program, its manual.
                case "$(printf '%s' "$_row" | cut -d'|' -f6)" in t|h) man_pages_for $_apks ;; esac
                # Its plugins, codecs and helpers, and the groups it needs.
                optionals_for $_apks
                access_fix
            else _rc=1; fi
        fi
        # Flathub rows belong to the catalogue, and copal-install knows them.
        # shellcheck disable=SC2086
        [ -z "$_flat" ] || { have copal-install && copal-install $_flat; } || _rc=1
        if [ "$_rc" = 0 ]; then store_event "$_id" program ok "\"n\":$_n,\"of\":$_of"
        else store_event "$_id" program failed "\"n\":$_n,\"of\":$_of"; fi
        [ "$_prc" = 0 ] || _rc=$_prc
    done
    COPAL_PROGRAM=""
    store_event run run "$([ "$_rc" = 0 ] && echo ok || echo failed)" "\"of\":$_of"
    if [ "$_batch" = 1 ]; then
        unset COPAL_STORE_BATCH
        [ "${COPAL_STORE_KEEP_BUILD_DEPS:-0}" = 1 ] || apk del -q .copal-store-build-batch >/dev/null 2>&1 || true
    fi
    refresh_menu
    return $_rc
}

remove_ids() {
    _rc=0
    for _id in "$@"; do
        _row=$(row_for "$_id"); [ -n "$_row" ] || { warn "nothing called '$_id'"; _rc=1; continue; }
        _inst=$(printf '%s' "$_row" | cut -d'|' -f4)
        _apks=""
        for _p in $_inst; do
            case "$_p" in
                *@source)  remove_recipe "${_p%@source}" || _rc=1 ;;
                *@clone)   note "${_p%@clone} is a checkout in ~/code, and is left alone: deleting somebody's work is not a list's job" ;;
                *@flathub) have flatpak && flatpak uninstall -y "${_p%@flathub}" || _rc=1 ;;
                *)         _apks="$_apks ${_p%@testing}" ;;
            esac
        done
        # shellcheck disable=SC2086
        [ -z "$_apks" ] || apk del $_apks || _rc=1
    done
    refresh_menu
    return $_rc
}

# The menu opens from a cached list; rebuild it as the person who asked.
refresh_menu() {
    if [ -n "${DOAS_USER:-}" ] && have copal-menu; then
        su "$DOAS_USER" -s /bin/sh -c 'copal-menu --rebuild-all' >/dev/null 2>&1 &
    fi
    return 0
}

info_id() {
    _row=$(status_rows | awk -F'|' -v q="$1" 'tolower($2) == tolower(q)')
    [ -n "$_row" ] || { _r=$(row_for "$1"); [ -n "$_r" ] && _row=$(status_rows | awk -F'|' -v q="${_r%%|*}" '$2 == q'); }
    [ -n "$_row" ] || die "nothing called '$1'"
    printf '%s' "$_row" | awk -F'|' '{
        printf "%s\n\n", $4
        if ($8 != "") printf "%s\n\n", $8
        printf "  section    %s\n  status     %s\n  command    %s\n", $3, $1, $6
        if ($9 != "") printf "  source     %s\n", $9
        printf "  listed in  the %s\n", ($10 == "store" ? "store" : "catalogue (stage 12)")
    }'
    printf '  installs   '; how_installed "$(printf '%s' "$_row" | cut -d'|' -f5)" | sed '2,$s/^/             /'
}

list_rows() {  # [section]
    status_rows | awk -F'|' -v s="${1:-}" '
        s == "" || tolower($3) == tolower(s) { printf "%-9s  %-12s  %-22s  %s\n", $1, $3, $2, $4 }'
}

sections() {
    status_rows | awk -F'|' '{ n[$3]++; if ($1 == "installed") i[$3]++ }
        END { for (s in n) printf "%s|%d|%d\n", s, n[s], i[s] + 0 }' | sort
}

# ------------------------------------------------------------ the window ---
#
# Pi-Apps' shape, which is the right one: sections first, then the programs
# in one, then a page about one program with its buttons. Every install and
# removal runs in a terminal window, so the apk output or the compiler's is
# there to read, and the list is redrawn afterwards with the new status.
in_terminal() {  # <copal-store verb and ids>
    _c="copal-store $*; printf '\\nPress Enter to close.'; read _"
    [ "$(id -u)" = 0 ] || _c="doas $_c"
    $TERM_EMU -e sh -c "$_c"
}

run_detached() {  # <shell command>
    ( setsid sh -c "$1" >/dev/null 2>&1 & )
}

gui_program() {  # <id>
    while :; do
        _row=$(status_rows | awk -F'|' -v q="$1" '$2 == q')
        [ -n "$_row" ] || return 0
        _st=$(printf '%s' "$_row" | cut -d'|' -f1)
        _label=$(printf '%s' "$_row" | cut -d'|' -f4)
        _bin=$(printf '%s' "$_row" | cut -d'|' -f6)
        _mode=$(printf '%s' "$_row" | cut -d'|' -f7)
        _home=$(printf '%s' "$_row" | cut -d'|' -f9)
        _text=$(info_id "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        if [ "$_st" = installed ]; then
            set -- "$1" --button="Back:1" --button="Remove:4" --button="Open:5"
        else
            set -- "$1" --button="Back:1" --button="Install:3"
        fi
        [ -n "$_home" ] && set -- "$@" --button="Website:6"
        _id="$1"; shift
        printf '%s\n' "$_text" | yad --text-info --wrap --title="$_label -- Copal Store" \
            --width=640 --height=420 --center "$@" 2>/dev/null
        _rc=$?; set -- "$_id"
        case "$_rc" in
            3) in_terminal install "$_id" ;;
            4) in_terminal remove "$_id" ;;
            5) _c=$(cmd_for "$_bin" "$_mode") && run_detached "$_c"; return 0 ;;
            6) run_detached "xdg-open '$_home'" ;;
            *) return 0 ;;
        esac
    done
}

gui_section() {  # <section>
    while :; do
        _pick=$(status_rows | awk -F'|' -v s="$1" -v OFS='\n' '
                    $3 == s { d = ($8 != "" ? $8 : "(from the catalogue)"); if (length(d) > 90) d = substr(d, 1, 87) "..."
                              print $2, ($1 == "installed" ? "installed" : ""), $4, d }' \
                | yad --list --title="$1 -- Copal Store" --width=900 --height=560 --center \
                      --text="Double-click a program to read about it, install it, or open it." \
                      --column="id:HD" --column="Status" --column="Program" --column="What it is" \
                      --search-column=3 --expand-column=4 --print-column=1 \
                      --button="Back:1" --button="Details:0" 2>/dev/null) || return 0
        _pick=${_pick%%|*}
        [ -n "$_pick" ] && gui_program "$_pick"
    done
}

gui() {
    while :; do
        _pick=$(sections | awk -F'|' -v OFS='\n' '{ print $1, $2, ($3 > 0 ? $3 : "") }' \
                | yad --list --title="Copal Store" --width=520 --height=600 --center \
                      --text="<b>Copal Store</b>\nPrograms ported from Pi-Apps and the Copal catalogue, by what they do.\nMost come from Alpine; the rest are compiled here from their GitHub source." \
                      --column="Section" --column="Programs:NUM" --column="Installed:NUM" \
                      --print-column=1 --button="Close:1" --button="Open:0" 2>/dev/null) || exit 0
        _pick=${_pick%%|*}
        [ -n "$_pick" ] && gui_section "$_pick"
    done
}

# The same three levels under dialog, in a terminal or on the console.
tui() {
    _t="${TMPDIR:-/tmp}/copal-store.$$"
    trap 'rm -f "$_t"' EXIT
    while :; do
        sections > "$_t"; set --
        while IFS='|' read -r _s _n _i; do set -- "$@" "$_s" "$_n programs, $_i installed"; done < "$_t"
        _sec=$(dialog --clear --title "Copal Store" --menu "Pick a section." 22 64 16 "$@" 3>&1 1>&2 2>&3) || { clear; exit 0; }
        while :; do
            status_rows | awk -F'|' -v s="$_sec" '$3 == s' > "$_t"; set --
            while IFS='|' read -r _st _id _s _l _rest; do
                set -- "$@" "$_id" "$( [ "$_st" = installed ] && printf '* ' || printf '  ')$_l"
            done < "$_t"
            _id=$(dialog --clear --title "$_sec" --menu "* = installed" 22 76 16 "$@" 3>&1 1>&2 2>&3) || break
            _act=$(dialog --clear --title "$_id" --menu "$(info_id "$_id" | head -n 3 | tr '\n' ' ')" 16 76 4 \
                     install "Install it" remove "Remove it" back "Back" 3>&1 1>&2 2>&3) || continue
            clear
            case "$_act" in
                install) if [ "$(id -u)" = 0 ]; then install_ids "$_id"; else doas "$0" install "$_id"; fi ;;
                remove)  if [ "$(id -u)" = 0 ]; then remove_ids "$_id"; else doas "$0" remove "$_id"; fi ;;
                *) continue ;;
            esac
            printf '\nPress Enter.'; read -r _
        done
    done
}

# ------------------------------------------------------------ self-test ---
#
# What 'make lint' asks of the table, offline. Each line printed is one
# check; a failure prints what failed and returns non-zero.
#   - every row has the eight fields, a one-word section, a mode, a gate
#   - ids are unique within the table
#   - every recipe@source names a recipe here with its three functions,
#     and every recipe is installed by some row
#   - no row repeats a program the catalogue already lists (COPAL_CATFILE,
#     which lint extracts from copal-prep.sh)
#   - no recipe carries a checksum left as a placeholder
self_test() {
    _rc=0
    store_table | awk -F'|' '
        NF != 8                              { print "  bad row, " NF " fields: " $0; bad = 1; next }
        $1 !~ /^[A-Z][a-z]+$/                { print "  bad section: " $1; bad = 1 }
        $5 !~ /^[xth-]$/                     { print "  bad mode for " $2 ": " $5; bad = 1 }
        $6 !~ /^(\*|64|!(v6|v7|x32|x64|a64))(,(64|!(v6|v7|x32|x64|a64)))*$/ { print "  bad gate for " $2 ": " $6; bad = 1 }
        END { exit bad }' || _rc=1
    [ $_rc = 0 ] && printf 'ok      copal-store table: %s rows, fields, sections, modes, gates\n' "$(store_table | grep -c .)"

    _dup=$(store_table | awk -F'|' '{ id = $4; if (id == "-") { split($3, p, " "); id = p[1]; sub(/@.*/, "", id) } print id }' | sort | uniq -d)
    if [ -n "$_dup" ]; then echo "  ids used twice: $_dup"; _rc=1
    else echo "ok      copal-store ids are unique"; fi

    _used=$(store_table | tr '|' '\n' | tr ' ' '\n' | sed -n 's/@source$//p' | sort -u)
    _r_ok=1
    for _r in $_used; do
        is_recipe "$_r" || { echo "  row asks for recipe '$_r', which is not in RECIPES"; _r_ok=0; continue; }
        for _f in bdeps rdeps install; do
            type "${_r}_$_f" >/dev/null 2>&1 || { echo "  recipe $_r has no ${_r}_$_f"; _r_ok=0; }
        done
    done
    for _r in $RECIPES; do
        printf '%s\n' "$_used" | grep -qx "$_r" || { echo "  recipe $_r is installed by no row"; _r_ok=0; }
    done
    if [ $_r_ok = 1 ]; then printf 'ok      copal-store recipes: %s, each with a row and its functions\n' "$(echo $RECIPES | wc -w)"
    else _rc=1; fi

    if grep -qE '0{64}' "$0"; then echo "  a placeholder checksum is still in $0"; _rc=1
    else echo "ok      copal-store checksums: none left as placeholders"; fi

    if [ -f "$CATFILE" ]; then
        _clash=$( { store_table | awk -F'|' '$4 != "-" { print $4 }' | sort -u
                    awk -F'|' 'NF >= 5 && $4 != "" { print $4 }' "$CATFILE" | sort -u; } | sort | uniq -d)
        if [ -n "$_clash" ]; then echo "  listed in both the store and the catalogue: $_clash"; _rc=1
        else printf 'ok      copal-store and the catalogue list no program twice (%s catalogue rows)\n' "$(grep -c '|' "$CATFILE")"; fi
    fi
    return $_rc
}

# ------------------------------------------------------------ dispatch ---
case "${1:-}" in
    list)     shift; list_rows "${1:-}" ;;
    sections) sections | awk -F'|' '{ printf "%-13s %3d programs, %d installed\n", $1, $2, $3 }' ;;
    info)     [ $# -ge 2 ] || die "info needs an id"; info_id "$2" ;;
    install)  shift; [ $# -gt 0 ] || die "install what?"; need_root install "$@"; install_ids "$@" ;;
    access)   shift; need_root access "$@"; access_fix "${1:-}" ;;
    manpages) shift; [ $# -gt 0 ] || die "man pages for what?"; need_root manpages "$@"
              man_pages_for "$@" ;;
    optionals)
              shift
              if [ $# -eq 0 ]; then optionals_table | awk -F'|' '{ printf "%-16s %s\n", $1, $2 }'
              else need_root optionals "$@"
                   if [ "$1" = --installed ]; then optionals_installed; else optionals_for "$@"; fi
              fi ;;
    playbook) [ $# -ge 2 ] || die "playbook of what?"; playbook_show "$2" ;;
    rows)     rows_status ;;
    pending)  shift; for _id in "$@"; do
                  _row=$(row_for "$_id"); [ -n "$_row" ] || continue
                  installed_id "$(printf '%s' "$_row" | cut -d'|' -f5)" "$(printf '%s' "$_row" | cut -d'|' -f4)" || printf '%s\n' "$_id"
              done ;;
    events)   tail -n "${2:-20}" "$EVENTS" 2>/dev/null || note "no events yet ($EVENTS)" ;;
    bundle)   [ $# -ge 2 ] || { store_bundles; exit 0; }; store_bundle "$2" || die "no bundle called '$2' -- one of: $(store_bundles)" ;;
    summary)  if [ -s "$LOGDIR/summary.txt" ]; then cat "$LOGDIR/summary.txt"; else note "no builds recorded yet"; fi ;;
    log)      [ -n "${2:-}" ] || die "log of what?"
              if [ -f "$LOGDIR/$2.log.gz" ]; then zcat "$LOGDIR/$2.log.gz"
              elif [ -f "$LOGDIR/$2.log" ]; then cat "$LOGDIR/$2.log"
              else die "no build log for $2 in $LOGDIR"; fi ;;
    remove)   shift; [ $# -gt 0 ] || die "remove what?"; need_root remove "$@"; remove_ids "$@" ;;
    recipes)  for _r in $RECIPES; do printf '%s\n' "$_r"; done ;;
    self-test) self_test ;;
    __build)  set -e; cd "$W"; "${2}_install" ;;   # build_recipe's worker, in its own shell
    deps)     [ $# -ge 2 ] && is_recipe "$2" || die "deps needs a recipe"
              printf 'build: %s\nrun: %s\n' "$("$2_bdeps")" "$("$2_rdeps")" ;;
    tui)      tui ;;
    section)  [ $# -ge 2 ] || die "section needs a name"; gui_section "$2" ;;
    show)     [ $# -ge 2 ] || die "show needs an id"; _r=$(row_for "$2"); [ -n "$_r" ] || die "nothing called '$2'"
              gui_program "${_r%%|*}" ;;
    -h|--help|help) sed -n '5,15p' "$0" | sed 's/^# \{0,1\}//' ;;
    '')
        if { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; } && have yad; then gui
        elif have dialog; then tui
        else list_rows; fi ;;
    *) die "unknown verb '$1' -- copal-store --help" ;;
esac
COPALSTORE
    chmod 0755 /usr/local/bin/copal-store
    STORE_STARTER=$(/usr/local/bin/copal-store bundle starter)
    STORE_FULL=$(/usr/local/bin/copal-store bundle full-monty)
    # Copal Apps (tools/copal-apps, copied in by 'make sync-apps'): the store's
    # programs with their status and their details, and every install shown
    # as it happens -- a slideshow of the program arriving, with three bars.
    cat > /usr/local/bin/copal-apps <<'COPALAPPS'
#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
"""copal-apps -- Copal Apps: the programs Copal offers, and their installs as they happen.

  copal-apps              the list: shelves, programs and their status, one program in full
  copal-apps --progress   the install that is running, as a slideshow with three bars
  copal-apps --follow     the same, but only if an install is queued or running; else nothing
  copal-apps ID           the list, opened on that program

TWO VIEWS OF ONE THING.  Every program is a playbook (docs/playbooks-plan.md),
and copal-store runs them.  This window never installs anything by itself and
never needs root: the list comes from 'copal-store rows' and 'copal-store
playbook ID', and the progress from the event stream copal-store writes,
/var/log/copal/events, one JSON line per run, program and step.  Install and
Remove open a terminal running 'doas copal-store install ID', so the password
is asked where passwords are asked, and this window follows the events.

THE SLIDESHOW.  While an install runs, the window shows the program arriving:
its picture, its name, its two sentences, where it comes from, and its steps
(deps, pre, install, post) ticked off as they finish.  Three bars sit under it:
the run (programs done of all), the program (steps done of its steps), and
the step itself -- read from the build log the install event names, ninja's
[n/m] or make's percentage, or a pulse where the build prints neither.

THE FIRST LOGIN.  The full monty queues its programs (/var/lib/copal/apps-queue)
for a boot service to install as root; the desktop starts 'copal-apps
--follow', which opens on the slideshow while that runs and stays away when
nothing is queued or running.

PICTURES are the gallery's, docs/img/gallery/ID.jpg on GitHub, fetched once
into ~/.cache/copal-apps and kept; without one, the program's icon.
"""
import json, os, re, shutil, subprocess, sys, threading, time, urllib.request

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib, Gtk, Pango  # noqa: E402

STORE = os.environ.get("COPAL_STORE") or shutil.which("copal-store") or "/usr/local/bin/copal-store"
EVENTS = os.environ.get("COPAL_EVENTS", "/var/log/copal/events")
QUEUE = os.environ.get("COPAL_APPS_QUEUE", "/var/lib/copal/apps-queue")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "copal-apps", "pictures")
GALLERY = "https://raw.githubusercontent.com/copallinux/copal/main/docs/img/gallery/%s.jpg"
STEPS = ("deps", "pre", "install", "post")
MARK = {"ok": "✓", "failed": "✗", "start": "▸", None: "·"}
PIC_W, PIC_H = 320, 200


# ------------------------------------------------------------------ data ---

def store(*args):
    try:
        return subprocess.run([STORE] + list(args), capture_output=True, text=True, timeout=120).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def load_rows():
    """The programs: id, shelf, label, install, bin, mode, about, home, origin, status."""
    keys = ("id", "shelf", "label", "install", "bin", "mode", "about", "home", "origin", "status")
    rows = []
    for line in store("rows").splitlines():
        f = line.split("|")
        if len(f) == len(keys):
            r = dict(zip(keys, f))
            # The store's programs, and the catalogue's graphical ones (the
            # terminal and command-line tools stay lists, docs/playbooks-plan.md).
            if r["origin"] == "store" or r["mode"] == "x":
                rows.append(r)
    return rows


def load_playbook(pid):
    """'copal-store playbook ID' as a dict; 'last' holds the last build's lines."""
    info, last, in_last = {}, [], False
    for line in store("playbook", pid).splitlines():
        if in_last:
            last.append(line.strip()); continue
        if line.strip() == "last build":
            in_last = True; continue
        m = re.match(r"^  (\S+)\s+(.*)$", line)
        if m:
            info[m.group(1)] = m.group(2)
        elif line and not line.startswith(" "):
            info["title"] = line
    info["last"] = last
    return info


class Events:
    """The event stream, read as it grows; the latest run in it, program by program."""

    def __init__(self, path):
        self.path, self.offset = path, 0
        self.reset()

    def reset(self):
        self.run = None            # {"of", "ids", "state", "t"}
        self.programs = {}         # id -> {"n", "label", "state", "steps", "playbook", "log", "t"}
        self.order = []
        self.current = None

    def poll(self):
        try:
            with open(self.path) as f:
                f.seek(self.offset)
                chunk = f.read()
                self.offset = f.tell()
        except OSError:
            return False
        changed = False
        for line in chunk.splitlines():
            try:
                e = json.loads(line)
            except ValueError:
                continue
            changed = True
            step, state, prog = e.get("step"), e.get("state"), e.get("program") or e.get("playbook")
            if step == "run":
                if state == "start":
                    self.reset()
                    self.run = {"of": e.get("of", 0), "ids": e.get("ids", "").split(), "state": "start", "t": e["t"]}
                elif self.run:
                    self.run["state"] = state
                continue
            if step == "stage" or prog is None:
                continue
            p = self.programs.get(prog)
            if p is None:
                p = self.programs[prog] = {"n": 0, "label": prog, "state": None, "steps": {}, "playbook": e.get("playbook"), "log": None, "t": e["t"]}
                self.order.append(prog)
            if step == "program":
                p["state"] = state
                p["n"] = e.get("n", p["n"])
                p["label"] = e.get("label", p["label"])
                if state == "start":
                    self.current = prog
            else:
                p["steps"][step] = state
                if step == "install" and e.get("log"):
                    p["log"] = e["log"]
                p["playbook"] = e.get("playbook", p["playbook"])
        return changed

    def active(self, within=6 * 3600):
        return bool(self.run and self.run["state"] == "start" and time.time() - self.run["t"] < within)


def step_fraction(log):
    """How far a build step has got, from its log's tail: ninja's [n/m], make's n%."""
    if not log:
        return None, ""
    try:
        with open(log, "rb") as f:
            f.seek(0, 2); size = f.tell(); f.seek(max(0, size - 8192))
            tail = f.read().decode("utf-8", "replace")
    except OSError:
        return None, ""
    m = None
    for m in re.finditer(r"\[\s*(\d+)/(\d+)\]", tail):
        pass
    if m and int(m.group(2)) > 0:
        return int(m.group(1)) / int(m.group(2)), "%s of %s" % (m.group(1), m.group(2))
    m = None
    for m in re.finditer(r"\[\s*(\d{1,3})%\]", tail):
        pass
    if m:
        return int(m.group(1)) / 100.0, m.group(1) + "%"
    return None, ""


def picture(pid, done):
    """Call done(path or None) with the program's gallery picture, fetching it once."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, pid + ".jpg")
    if os.path.exists(path):
        done(path if os.path.getsize(path) > 0 else None); return
    def fetch():
        ok = False
        try:
            with urllib.request.urlopen(GALLERY % pid, timeout=10) as r, open(path + ".part", "wb") as f:
                f.write(r.read()); ok = True
        except Exception:
            pass
        if ok:
            os.replace(path + ".part", path)
        else:
            open(path, "wb").close()        # remembered as absent; delete the file to retry
        GLib.idle_add(done, path if ok else None)
    threading.Thread(target=fetch, daemon=True).start()


def set_picture(image, pid, icon):
    def done(path):
        if path:
            try:
                image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(path, PIC_W, PIC_H, True)); return
            except GLib.Error:
                pass
        image.set_from_icon_name(icon if Gtk.IconTheme.get_default().has_icon(icon) else "application-x-executable", Gtk.IconSize.DIALOG)
        image.set_pixel_size(96)
    picture(pid, done)


def terminal(cmd):
    """A terminal window running cmd, left open until Enter so the output can be read."""
    for t in (os.environ.get("TERMINAL"), "kitty", "foot", "alacritty", "xfce4-terminal", "xterm"):
        if t and shutil.which(t):
            sh = cmd + "; printf '\\nPress Enter to close.'; read _"
            subprocess.Popen([t, "-e", "sh", "-c", sh])
            return True
    return False


def label(text="", css=None, wrap=False, xalign=0.0, select=False):
    lab = Gtk.Label(label=text, xalign=xalign)
    if wrap:
        lab.set_line_wrap(True); lab.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
    if css:
        lab.get_style_context().add_class(css)
    lab.set_selectable(select)
    return lab


# ------------------------------------------------------------- progress ---

class Progress(Gtk.Box):
    """The slideshow: the program arriving, its steps, and three nested bars."""

    def __init__(self, rows_by_id):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.set_border_width(18)
        self.rows = rows_by_id
        self.events = Events(EVENTS)
        self.shown = None

        slide = Gtk.Box(spacing=18)
        self.image = Gtk.Image(); self.image.set_size_request(PIC_W, PIC_H)
        slide.pack_start(self.image, False, False, 0)
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.title = label(css="copal-title", wrap=True)
        self.about = label(wrap=True)
        self.source = label(css="dim-label", wrap=True)
        self.steps = label(css="copal-steps")
        for w in (self.title, self.about, self.source, self.steps):
            text.pack_start(w, False, False, 0)
        slide.pack_start(text, True, True, 0)
        self.pack_start(slide, False, False, 0)

        self.bars = []
        for _ in range(3):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
            cap = label(css="dim-label")
            bar = Gtk.ProgressBar(); bar.set_show_text(True)
            box.pack_start(cap, False, False, 0); box.pack_start(bar, False, False, 0)
            self.pack_start(box, False, False, 0)
            self.bars.append((cap, bar))

        self.history = Gtk.FlowBox(); self.history.set_selection_mode(Gtk.SelectionMode.NONE)
        self.history.set_max_children_per_line(6)
        self.pack_start(label("Done", css="dim-label"), False, False, 0)
        self.pack_start(self.history, False, False, 0)
        self.status = label(wrap=True)
        self.pack_start(self.status, False, False, 0)
        self.hist_n = -1
        GLib.timeout_add(500, self.tick)
        self.tick()

    def tick(self):
        self.events.poll()
        ev = self.events
        if not ev.run:
            self.title.set_markup("<big><b>Nothing is being installed</b></big>")
            self.about.set_text("Install a program from the list, and it arrives here: what it is, its steps, and how far each has got.")
            for cap, bar in self.bars:
                cap.set_text(""); bar.set_fraction(0); bar.set_text("")
            return True
        of = ev.run["of"] or len(ev.order)
        done = sum(1 for p in ev.programs.values() if p["state"] in ("ok", "failed"))
        cur = ev.current and ev.programs.get(ev.current)
        if cur and cur is not self.shown:
            self.show_program(ev.current, cur)
        if cur:
            self.shown = cur
            order = [s for s in STEPS if s in cur["steps"] or (s in ("deps", "install"))]
            marks = "   ".join("%s %s" % (MARK.get(cur["steps"].get(s)), s) for s in order)
            self.steps.set_markup("<tt>%s</tt>" % GLib.markup_escape_text(marks))
            nsteps = len(order) or 1
            sdone = sum(1 for s in order if cur["steps"].get(s) in ("ok", "failed"))
            running = next((s for s in order if cur["steps"].get(s) == "start"), None)
            cap, bar = self.bars[1]
            cap.set_text("%s -- step %d of %d" % (cur["label"], min(sdone + 1, nsteps), nsteps))
            bar.set_fraction(sdone / nsteps); bar.set_text(running or ("done" if cur["state"] == "ok" else ""))
            cap, bar = self.bars[2]
            if running == "install" and cur.get("log"):
                frac, what = step_fraction(cur["log"])
                cap.set_text("Compiling -- " + os.path.basename(cur["log"]))
                if frac is None:
                    bar.pulse(); bar.set_text("working")
                else:
                    bar.set_fraction(frac); bar.set_text(what)
            elif running:
                cap.set_text(running.capitalize()); bar.pulse(); bar.set_text("working")
            else:
                cap.set_text(""); bar.set_fraction(1 if cur["state"] == "ok" else 0); bar.set_text("")
        cap, bar = self.bars[0]
        cap.set_text("Programs -- %d of %d" % (min(done + (0 if ev.run["state"] != "start" else 1), of), of))
        bar.set_fraction(done / of if of else 0); bar.set_text("%d%%" % (100 * done // of if of else 0))
        finished = [p for p in ev.order if ev.programs[p]["state"] in ("ok", "failed")]
        if len(finished) != self.hist_n:
            self.hist_n = len(finished)
            for c in self.history.get_children():
                self.history.remove(c)
            for pid in finished:
                p = ev.programs[pid]
                self.history.add(label("%s %s" % (MARK[p["state"]], p["label"])))
            self.history.show_all()
        if ev.run["state"] != "start":
            bad = [ev.programs[p]["label"] for p in finished if ev.programs[p]["state"] == "failed"]
            self.status.set_markup("<b>Finished.</b> %d of %d installed.%s  'copal-store summary' has the record." % (
                len(finished) - len(bad), of, (" Not installed: " + ", ".join(bad) + ".") if bad else ""))
        else:
            self.status.set_text("")
        return True

    def show_program(self, pid, p):
        r = self.rows.get(pid, {})
        self.title.set_markup("<big><b>%s</b></big>" % GLib.markup_escape_text(p["label"]))
        self.about.set_text(r.get("about", ""))
        src = r.get("install", "")
        if src.endswith("@clone"):
            info = load_playbook(pid)
            self.source.set_text("Cloned into ~/code from " + info.get("source", "").replace("clone ", "", 1))
        elif src.endswith("@source"):
            info = load_playbook(pid)
            self.source.set_text("Compiled here from " + info.get("source", "its source"))
        elif src:
            self.source.set_text("From Alpine: apk add " + src.replace("@testing", " (edge/testing)"))
        set_picture(self.image, pid, r.get("bin") or pid)


# ------------------------------------------------------------------ list ---

class Details(Gtk.ScrolledWindow):
    """One program in full: picture, name, status, two sentences, source, needs, steps, last build."""

    def __init__(self, on_install, on_remove):
        super().__init__()
        self.on_install, self.on_remove = on_install, on_remove
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_border_width(16)
        self.image = Gtk.Image(); self.image.set_size_request(PIC_W, PIC_H)
        self.title = label(wrap=True)
        self.status = label(css="dim-label")
        self.about = label(wrap=True)
        self.grid = Gtk.Grid(column_spacing=12, row_spacing=6)
        buttons = Gtk.Box(spacing=6)
        self.b_install = Gtk.Button(label="Install"); self.b_remove = Gtk.Button(label="Remove")
        self.b_open = Gtk.Button(label="Open"); self.b_web = Gtk.Button(label="Website")
        for b in (self.b_install, self.b_remove, self.b_open, self.b_web):
            buttons.pack_start(b, False, False, 0)
        self.b_install.get_style_context().add_class("suggested-action")
        self.b_install.connect("clicked", lambda *_: self.row and self.on_install(self.row))
        self.b_remove.connect("clicked", lambda *_: self.row and self.on_remove(self.row))
        self.b_open.connect("clicked", lambda *_: self.row and subprocess.Popen([self.row["bin"]]))
        self.b_web.connect("clicked", lambda *_: self.row and subprocess.Popen(["xdg-open", self.row["home"]]))
        for w in (self.image, self.title, self.status, self.about, buttons, self.grid):
            box.pack_start(w, False, False, 0)
        self.add(box)
        self.row = None

    def show_row(self, r):
        self.row = r
        self.title.set_markup("<big><b>%s</b></big>" % GLib.markup_escape_text(r["label"]))
        self.status.set_text("%s  ·  %s" % (r["status"], r["shelf"]))
        self.about.set_text(r["about"])
        set_picture(self.image, r["id"], r["bin"] if r["bin"] != "-" else r["id"])
        installed = r["status"] == "installed"
        self.b_install.set_visible(not installed); self.b_remove.set_visible(installed)
        self.b_open.set_visible(installed and r["mode"] == "x")
        self.b_web.set_visible(bool(r["home"]))
        for c in self.grid.get_children():
            self.grid.remove(c)
        info = load_playbook(r["id"])
        rows = []
        if r["install"].endswith("@clone"):
            rows.append(("Source", "cloned into ~/code from " + info.get("source", "").replace("clone ", "", 1)
                         + ", and built there by copal-build"))
            rows.append(("To build", info.get("build", "") or "nothing more"))
            if info.get("runs"):
                rows.append(("To run", info["runs"]))
        elif r["install"].endswith("@source"):
            rows.append(("Source", "compiled here from " + info.get("source", "")))
            rows.append(("To build", info.get("build", "") or "nothing more"))
            rows.append(("To run", info.get("runs", "") or "only what the build links against"))
            if info.get("needs"):
                rows.append(("Needs first", info["needs"]))
        else:
            rows.append(("Source", "Alpine: " + r["install"].replace("@testing", " (edge/testing)")))
        rows.append(("Steps", info.get("steps", "")))
        if info["last"]:
            rows.append(("Last build", "\n".join(info["last"])))
        for i, (k, v) in enumerate(rows):
            self.grid.attach(label(k, css="dim-label"), 0, i, 1, 1)
            val = label(v, wrap=True, select=True); val.set_max_width_chars(60)
            if k == "Last build":
                val.get_style_context().add_class("monospace")
            self.grid.attach(val, 1, i, 1, 1)
        self.show_all()
        # A ~/code checkout is never removed by the store (it is somebody's
        # work), so it has no Remove button to promise that it would be.
        self.b_install.set_visible(not installed)
        self.b_remove.set_visible(installed and not r["install"].endswith("@clone"))
        self.b_open.set_visible(installed and r["mode"] == "x"); self.b_web.set_visible(bool(r["home"]))


class Apps(Gtk.Window):
    def __init__(self, page, select=None):
        super().__init__(title="Copal Apps")
        self.set_default_size(1100, 700)
        self.set_icon_name("system-software-install")
        self.rows = load_rows()
        by_id = {r["id"]: r for r in self.rows}

        hb = Gtk.HeaderBar(show_close_button=True, title="Copal Apps")
        self.set_titlebar(hb)
        self.stack = Gtk.Stack()
        sw = Gtk.StackSwitcher(stack=self.stack)
        hb.set_custom_title(sw)
        self.search = Gtk.SearchEntry(placeholder_text="Search")
        self.search.connect("search-changed", lambda *_: self.fill())
        hb.pack_end(self.search)

        # The list: shelves | programs | one program
        paned = Gtk.Paned()
        self.shelves = Gtk.ListBox()
        self.shelves.connect("row-selected", lambda *_: self.fill())
        for name in ["All"] + sorted({r["shelf"] for r in self.rows}):
            row = Gtk.ListBoxRow(); row.add(label(name)); row.name = name
            self.shelves.add(row)
        left = Gtk.ScrolledWindow(); left.add(self.shelves); left.set_size_request(170, -1)
        self.list = Gtk.ListBox()
        self.list.connect("row-selected", self.on_pick)
        mid = Gtk.ScrolledWindow(); mid.add(self.list); mid.set_size_request(330, -1)
        self.details = Details(self.install, self.remove)
        inner = Gtk.Paned(); inner.pack1(mid, False, False); inner.pack2(self.details, True, False)
        paned.pack1(left, False, False); paned.pack2(inner, True, False)
        self.stack.add_titled(paned, "list", "Programs")
        self.progress = Progress(by_id)
        self.stack.add_titled(self.progress, "progress", "Progress")
        self.add(self.stack)
        self.shelves.select_row(self.shelves.get_row_at_index(0))
        self.show_all()
        for row in self.list.get_children():
            if select and row.r["id"] == select:
                self.list.select_row(row)
        self.stack.set_visible_child_name(page)
        GLib.timeout_add_seconds(3, self.refresh_when_done)
        self.was_active = self.progress.events.active()

    def fill(self):
        sel = self.shelves.get_selected_row()
        shelf = sel.name if sel else "All"
        q = self.search.get_text().lower()
        for c in self.list.get_children():
            self.list.remove(c)
        for r in sorted(self.rows, key=lambda r: r["label"].lower()):
            if shelf != "All" and r["shelf"] != shelf:
                continue
            if q and q not in (r["label"] + " " + r["about"]).lower():
                continue
            row = Gtk.ListBoxRow(); row.r = r
            box = Gtk.Box(spacing=8); box.set_border_width(4)
            box.pack_start(label("●" if r["status"] == "installed" else "○"), False, False, 0)
            box.pack_start(label(r["label"]), True, True, 0)
            row.add(box)
            self.list.add(row)
        self.list.show_all()

    def on_pick(self, _lb, row):
        if row is not None:
            self.details.show_row(row.r)

    def install(self, r):
        if terminal("doas %s install %s" % (STORE, r["id"])):
            self.stack.set_visible_child_name("progress")

    def remove(self, r):
        terminal("doas %s remove %s" % (STORE, r["id"]))

    def refresh_when_done(self):
        active = self.progress.events.active()
        if self.was_active and not active:
            self.rows = load_rows(); self.fill()
        self.was_active = active
        return True


CSS = b"""
.copal-title { font-size: 150%; }
.copal-steps { font-family: monospace; }
.monospace { font-family: monospace; font-size: 90%; }
"""


def main():
    args = sys.argv[1:]
    if "-h" in args or "--help" in args:
        print(__doc__.split("\n\n")[1]); return 0
    if "--follow" in args:
        queued = os.path.exists(QUEUE) and os.path.getsize(QUEUE) > 0
        ev = Events(EVENTS); ev.poll()
        if not queued and not ev.active():
            return 0
    prov = Gtk.CssProvider(); prov.load_from_data(CSS)
    from gi.repository import Gdk
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    ids = [a for a in args if not a.startswith("-")]
    win = Apps("progress" if ("--progress" in args or "--follow" in args) else "list", ids[0] if ids else None)
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
COPALAPPS
    chmod 0755 /usr/local/bin/copal-apps
    # The menu entry keeps its file name, which copal-gui's favourites know.
    printf '[Desktop Entry]\nType=Application\nName=Copal Apps\nComment=Find programs by what they do, install them, and watch them arrive\nExec=copal-apps\nIcon=system-software-install\nCategories=System;PackageManager;\nTerminal=false\n' \
        > /usr/local/share/applications/copal-store.desktop
    note "/usr/local/bin/copal-store -- Super+Shift+C, or Copal Store at the top of the menu (Super+Z)"

    cat <<'MSG'

    The Copal Store is Pi-Apps' idea on Alpine: programs chosen for a desktop,
    grouped by what they do, each with a line saying what it is -- so a name
    you half remember can be found again. Nothing in it is installed until
    you pick it.

    Two sources, in this order. Programs Alpine does not package are compiled
    here from their own GitHub source, pinned to a release and checked by
    checksum: OpenShot, LibreCAD, VeraCrypt, Amiberry, DDNet, Marathon,
    Descent and others. Everything else is an Alpine package. Nothing comes
    from Flathub.

    A compiled program takes minutes to a quarter of an hour on a Pi 4.
    Its build dependencies are removed afterwards, and 'copal-store remove'
    takes away every file it installed.

MSG
    note "Starter set: $STORE_STARTER"
    note "(OpenShot is compiled -- 150 MB of source, a few minutes on four cores)"
    [ "${AUTO:-0}" = 1 ] && AUTO_DEFAULT=y
    if confirm_yes "Install the starter set now?"; then
        require_network || { warn "no network -- the store can install them later"; return 0; }
        _ok=""
        for _id in $STORE_STARTER; do
            # A row the table does not offer on this board is skipped, not
            # attempted: 'info' is how the store says whether it exists here.
            if /usr/local/bin/copal-store info "$_id" >/dev/null 2>&1; then
                /usr/local/bin/copal-store install "$_id" && _ok="$_ok $_id"
            else
                note "$_id is not offered for this board -- skipped"
            fi
        done
        note "installed:${_ok:- nothing}"
    else
        note "Skipped. Open the store any time: copal-store"
    fi
    # The optionals of everything installed so far -- the catalogue from
    # stage 12, the starter set just now: its plugins, codecs, image loaders
    # and helpers (copal-store's optionals_table says which, and which are
    # left out). What the store installs later brings its own.
    if require_network; then
        say "Optionals: plugins, codecs and helpers for what is installed"
        /usr/local/bin/copal-store optionals --installed || warn "some optionals did not install -- 'doas copal-store optionals --installed' retries"
    fi
    # And the groups they need: plugdev for SDR dongles, wireshark, dialout...
    /usr/local/bin/copal-store access "$PI_USER" || true
    if [ "$(copal_profile)" = full ]; then
        # QUEUED, NOT INSTALLED HERE. No desktop is running during the
        # automatic install -- it starts at the reboot that ends it -- and
        # these programs are the ones worth watching arrive. So they are
        # queued, and a boot service installs them as root through
        # copal-store, which writes its events as it goes; at the first
        # desktop login 'copal-apps --follow' opens on the slideshow. The
        # service installs only what is still missing, so a reboot in the
        # middle resumes, and removes itself when the queue is done.
        say "The full monty's programs: queued for the first desktop login"
        note "$(echo $STORE_FULL)"
        mkdir -p /var/lib/copal
        printf '%s\n' $STORE_FULL > /var/lib/copal/apps-queue
        cat > /etc/init.d/copal-apps-queue <<'QUEUESVC'
#!/sbin/openrc-run
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Paul Richeson -- part of Copal Linux.
# Written by stage 18: installs the programs queued in /var/lib/copal/apps-queue,
# in the background, through copal-store -- whose events copal-apps shows.
description="Copal Apps: install the queued programs"
depend() { need net; after firstboot local; }
start() {
    [ -s /var/lib/copal/apps-queue ] || return 0
    ebegin "Installing the queued programs in the background (copal-apps shows them)"
    start-stop-daemon --start --background --make-pidfile --pidfile /run/copal-apps-queue.pid \
        --exec /bin/sh -- -c '
            mkdir -p /var/log/copal-store
            _p=$(/usr/local/bin/copal-store pending $(cat /var/lib/copal/apps-queue))
            [ -z "$_p" ] || /usr/local/bin/copal-store install $_p >> /var/log/copal-store/queue.log 2>&1
            rm -f /var/lib/copal/apps-queue
            rc-update del copal-apps-queue default >/dev/null 2>&1'
    eend $?
}
QUEUESVC
        chmod 0755 /etc/init.d/copal-apps-queue
        rc-update add copal-apps-queue default >/dev/null 2>&1 \
            || warn "could not add copal-apps-queue to the default runlevel -- the queue waits for 'copal-store install'"
        note "queued in /var/lib/copal/apps-queue; the service copal-apps-queue installs them after the reboot"
        note "and Copal Apps opens on the slideshow at the first login -- 'copal-store summary' has the record"
    fi
    say "Stage 18 complete."
    commit_reminder
}
