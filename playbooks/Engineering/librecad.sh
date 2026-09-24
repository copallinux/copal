# playbook: librecad
# source:   github LibreCAD/LibreCAD
# build:    build-base cmake samurai qt5-qtbase-dev qt5-qtsvg-dev qt5-qttools-dev boost-dev
#           freetype-dev
# runs:     qt5-qtsvg
#
# program:  librecad
# label:    LibreCAD (2D CAD)
# shelf:    Engineering
# install:  librecad@source
# mode:     x
# gate:     64
# home:     https://github.com/LibreCAD/LibreCAD
# about:    Precise 2D drawing: floor plans, parts and schematics, in layers and blocks. It reads
#           and writes DXF, and reads DWG.

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
