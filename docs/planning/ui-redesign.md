# Authorized practice UI redesign

Implementation tracker: [armaan-io/rhythmic#3](https://github.com/armaan-io/rhythmic/issues/3).

The user confirmed shared understanding after Q62–106 and explicitly requested
implementation, commit, and push. This supersedes the earlier practice-version
visual styling, scoring formula, and always-accessible diagnostics decisions.

## Approved experience

- Library-first navigation: Quarters, Eighth Notes, Rests, Syncopation sections,
  visible exercise rows showing name and bar count. No category subpages/dashboard.
- Dedicated preparation, practice, review, and Settings. Diagnostics development-only.
- Preparation: compact BPM and volume buttons, notation, Listen and Play.
  Matching bottom sheets with immediate changes and Done; tempo slider/±1 controls,
  separate Metronome/Rhythm sliders. Listen stays in place; tempo disabled during
  listening, volume available. Play stops Listen and starts a fresh count-in.
- Musical area stays anchored between preparation, listening, and practice.
  One notation bar per row directly on background. Fixed numbered beat circles,
  muted vermilion active fill, phase label Count-in / Bar n of N / Listening · Bar n of N.
- Practice hides tempo/volume controls, replaces playback area with a large quiet
  pad, subtle neutral contact feedback, and Cancel away from the pad. No scrolling
  during performance; keep essentials visible. Cancel returns quietly to preparation.
- Optional light pad haptics, off by default, controlled from Settings.
- Review: whole-number score, unboxed adaptive five counts including zeros,
  timing timeline, then notation. Fixed bottom Retry returns to preparation;
  top Library returns directly to selection. Direct marker selection, matched-pair
  highlight, explanation beneath its bar, chooser only for overlapping candidates.
  Hollow targets / solid taps, true timing positions, no five-color judgments.
- On-demand How scoring works sheet. No result history or expanded curriculum.

## Revised scoring

`max(0, 100 * (onTime + 0.5 * (early + late) - extra) / targetCount)`.
Missed earns zero. Round nearest integer; reserve 100 exclusively for all targets
On time and no extras. Keep timing and matching windows unchanged. One On time
and three Early/Late scores 63; four On time plus one Extra scores 75.

## Visual and settings direction

Focused musical instrument with native iOS familiarity. Deep muted green accent,
warm near-white light background, subtly green charcoal dark background, native
typography, stable-width numbers. Quiet transitions; respect Reduce Motion.
No color-coded skill categories or decorative cards around notation.

Settings: Audio, Appearance (System default / Light / Dark), optional haptics.
Appearance and both volume levels persist. Tempos remain session-only at 80 BPM
on relaunch; no persistent attempts. Audio controls in Settings and preparation
edit the same preferences.

Inline interruption notices; no notice for manual Cancel. Bluetooth warning on
preparation only with on-demand explanation. Accessible navigation, descriptions,
and review; no untested promise of VoiceOver real-time performance. Larger text
may scroll outside active practice. Device validation required for small-screen
layout, contrast, notation, haptics, and touch/audio responsiveness.

## Scope boundary

Retain four exercises, matching rules, timing windows, portrait iPhone, all audio
and touch timing semantics. No accounts, networking, curriculum expansion, or
history. Changes in this document are explicitly authorized exceptions to the
original UI-only boundary (scoring, preference persistence, optional haptics).
