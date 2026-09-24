# playbook: fraqtive
# source:   github mimecorg/fraqtive
# build:    build-base qt5-qtbase-dev mesa-dev glu-dev
# runs:
#
# program:  fraqtive
# label:    Fraqtive (Mandelbrot fractals)
# shelf:    Science
# install:  fraqtive@source
# mode:     x
# gate:     !v6
# home:     https://fraqtive.mimec.org/
# about:    A fast generator of Mandelbrot-family fractals, with presets, colour gradients and
#           high-resolution image export. Its 3D view needs desktop OpenGL, so on ARM boards it
#           stays black; the 2D view is the program.

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
