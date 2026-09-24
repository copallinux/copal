# playbook: stage-workshop
# source:   copal
# origin:   stage
# stage:    14
# category: Workshop
# step:     CAD, 3D printing, EDA, LaTeX, trackers
# weight:   6
# levels:   medium full
# summary:  CAD, 3D printing, electronics design, lab instruments, LaTeX and music trackers. The
#           workbench, for the projects that are not software.

stage_workshop() {
    say "Stage 14: the workshop -- engineering, science and music"

    require_disk_root "The workshop bundles (CAD, EDA, LaTeX)" || return 0
    require_network || return 1

    note "architecture: $(apk --print-arch 2>/dev/null || echo unknown)  (gate: $ARCH_GATE)"
    cat <<'MSG'

    Eight bundles. Each says what it can and cannot do on this board before
    it installs anything.

      c   CAD and 3D modelling      SolveSpace, FreeCAD, Blender, Goxel
      p   3D printing (Ender 3)     CuraEngine + slice-ender3, admesh,
                                    optionally OctoPrint and the Cura GUI
      e   Electronics               ngspice, KiCad, and pcbzip for the fab
      i   Instruments               ADALM2000, ADALM-Pluto, IIO: libiio and
                                    iiod, pyadi-iio, libm2k, the oscilloscope,
                                    GNU Radio blocks (mostly compiled)
      m   LaTeX and mathematics     TeX Live, Maxima + wxMaxima, Octave, SymPy,
                                    Gnuplot
      u   Music                     trackers, SID, MIDI, Hydrogen, Audacity
      k   Learning to play piano    PianoBooster (compiles), piano-midi
      w   Windows programs          Wine in sandboxed boxes; Notepad++, 7-Zip
      a   All of them
      q   Back to the menu

MSG
    ask "Choose [c/p/e/i/m/u/k/w/a/q]:"
    case "$REPLY" in
        c|C) workshop_cad ;;
        p|P) workshop_3dprint ;;
        e|E) workshop_electronics ;;
        i|I) workshop_iio ;;
        m|M) workshop_maths ;;
        u|U) workshop_music ;;
        k|K) workshop_piano ;;
        w|W) workshop_windows ;;
        a|A) workshop_cad; workshop_3dprint; workshop_electronics
             workshop_iio; workshop_maths; workshop_music; workshop_piano; workshop_windows ;;
        *)   note "Nothing installed."; return 0 ;;
    esac

    say "Stage 14 complete."
    commit_reminder
}
