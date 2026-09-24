# playbook: openshot
# source:   github OpenShot/libopenshot-audio
# build:    build-base cmake samurai swig python3-dev qt6-qtbase-dev qt6-qtsvg-dev ffmpeg-dev
#           zeromq-dev cppzmq jsoncpp-dev alsa-lib-dev babl-dev
# runs:     py3-qt6 py3-pyzmq py3-requests py3-defusedxml qt6-qtsvg ffmpeg-libavcodec
#           ffmpeg-libavformat ffmpeg-libswscale ffmpeg-libswresample jsoncpp libzmq
#
# program:  openshot-qt
# label:    OpenShot (video editor)
# shelf:    Multimedia
# install:  openshot@source
# mode:     x
# gate:     64
# home:     https://github.com/OpenShot/openshot-qt
# about:    A video editor to cut clips, lay them on tracks, and add titles, transitions and
#           effects, then export for the web. Compiled here from GitHub: libopenshot-audio,
#           libopenshot and openshot-qt.

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
