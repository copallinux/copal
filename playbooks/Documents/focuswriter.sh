# playbook: focuswriter
# source:   github gottcode/focuswriter
# build:    build-base cmake samurai pkgconf qt6-qtbase-dev qt6-qttools-dev qt6-qtmultimedia-dev
#           hunspell-dev kdsingleapplication-dev zlib-dev
# runs:     hunspell-en
#
# program:  focuswriter
# label:    FocusWriter (distraction-free writing)
# shelf:    Documents
# install:  focuswriter@source
# mode:     x
# gate:     *
# home:     https://github.com/gottcode/focuswriter
# about:    A full-screen writing window with nothing in it but the text: themes, daily goals,
#           timers and alarms, typewriter sounds, and a spell checker. Opens and saves plain text,
#           RTF, ODT and DOCX.

# FocusWriter: a full-screen writing program, CMake over Qt 6 and Hunspell.
# Nothing to repair; Alpine has every library, KDSingleApplication included.
FOCUSWRITER_VER=1.9.1
focuswriter_install() {
    _s=$(gh_source gottcode/focuswriter "v$FOCUSWRITER_VER" \
         ca83cade13158111e19eeba86d0a043bb45be4f32bd82f43da2bb910c0edd32d) || return 1
    cmake_stage "$_s" || return 1
}
