# Four-exercise practice version: validation and device checklist

Scope: [approved decisions 49–61](planning/practice-version.md),
[GitHub issue #2](https://github.com/armaan-io/rhythmic/issues/2).
The user's acceptance of the original timing build is recorded separately in
[timing-test validation](timing-test-validation.md). It does **not** automatically
validate this version's new audio, notation, matching integration, or review UI.

## Implementation-session results

- **Full XCTest suite: 22 passed, 0 failures** (13 practice-session tests and 9
  unchanged timing-session tests), using Swift 6.2.3 on Linux.
- Core compilation with `swift build -Xswiftc -warnings-as-errors`: passed.
- Focused practice tests were run throughout development; new behavior and the
  review-discovered rounding/drain fixes followed red/green cycles at the approved seam.
- All iOS files passed Swift frontend syntax parsing in Swift 5 mode. This is
  not Apple SDK typechecking.
- XcodeGen 2.46.0 successfully regenerated the project, including new iOS files.
- Git whitespace checks passed.
- **Standards review:** zero outstanding documented-rule or smell findings;
  correctness findings about uptime-dependent rounding and a delayed engine
  notification were fixed and re-reviewed.
- **Spec review:** zero outstanding findings after fixing rounding, input draining,
  and the beat indicator's placement above the staff.

Reviews used pre-implementation commit `a6a20b44f86e72120996e4343f1f6f5001e8f14e`
as the fixed baseline. No Apple SDK build, simulator run, signing, or physical
iPhone test was available in this implementation session. In particular, **the
new snare's audibility has not yet been verified by listening on your device**.

## Build on the Mac

Use Xcode 16+ with device support for your iPhone (minimum iOS 17). In the updated
repository run:

```sh
xcodegen generate
open RhythmTiming.xcodeproj
```

Reapply your signing team/bundle identifier if regenerating overwrote project-only
edits. Keep a local copy of those settings; never commit signing credentials.
The app display name is **Rhythm Trainer**, version 1.1, build 2.
See [the existing setup guide](timing-test-device-guide.md#build-on-a-mac) for
XcodeGen installation and signing details. No new third-party runtime dependencies
or microphone permissions are needed.

## Automated boundary

`PracticeSession` takes an exercise, tempo, monotonic start time, timestamped
contacts, and lifecycle actions. It returns audio schedules, phases, and the
complete result data. Tests observe this public boundary, not private matcher
implementation. Coverage includes:

- Four exactly specified patterns and complete notation measures.
- Listen without a count-in, Start replacing Listen with a new four-beat count-in,
  performance through trailing rests, and repeat attempts.
- Approved timing windows at 30, 60, 90, 120 and 240 BPM, inclusive boundaries,
  and values just outside each boundary.
- Pre-downbeat first-note matching, ignored warmups, opening rests, extras/misses,
  stable matching for duplicate and out-of-order contacts, whole-phrase objective
  priorities and paired timeline identifiers.
- 100/88/89 score examples, smooth partial credit, no timestamp realignment,
  no-tap attempts, invalid inputs, cancellation, and bounded contact memory.
- Stable half-point rounding at multiple uptime magnitudes and explicit deferred
  finalization while draining separate input batches after the end observation.

Run `swift build`, `swift test --filter PracticeSessionTests`, and `swift test`.
The original `TimingSessionTests` remain part of the full suite. Linux Swift
compilation validates the core, **not** SwiftUI/UIKit/AVFoundation. Syntax parsing
of iOS sources and XcodeGen generation are useful additional checks but cannot
substitute for an Apple SDK build or physical-device testing.

## Real-iPhone checklist

Record the tested commit, Xcode/iOS versions, device, route, BPM, and failures.
Do not call untested cases passed. Speaker and wired routes are the primary
timing reference; Bluetooth stays allowed with an explicit warning, not calibration.

1. **Notation:** inspect all four exercises at normal and large text sizes, in
   light and dark appearance. Five staff lines, percussion clef, 4/4, notes,
   rests, stems/flags, paired eighth beams and bar numbers must be readable.
   Check that required onsets match the approved table exactly. Four eighth-note
   pairs must not look like quarter notes; offbeat rests must remain distinct.
   The renderer uses vector glyphs for this limited vocabulary, not a music font.
2. **Listen:** each phrase plays once, with metronome and snare starting together
   (an opening rest still has a click). No musical count-in. Pad does not sound.
   Tempo is locked. Stop Listening returns to preparation. Start during listening
   stops the old audio and creates a fresh four-click count-in with no overlap.
3. **Sound:** compare dry snare against the metronome on the built-in speaker.
   It should be easier to hear than the previous low hit, without clipping or
   ringing into the next eighth note at 240 BPM. Confirm the demo and pad timbre
   agree and the two volume controls affect the correct sounds. Bursts share
   gain across active tap voices to preserve headroom; audibility needs listening,
   not just sample inspection. Test the diagnostic pad too.
4. **Count-in/performance:** four audible clicks and separate 1–2–3–4 indicator.
   Count-in pad taps sound, but ordinary warmups do not appear as extras. A nearby
   anticipatory first-note tap may match only a note beginning on the downbeat.
   Space between notes starts with a rest: tapping that rest is an extra; tapping
   before the downbeat is ignored. Performance continues through trailing rests.
5. **Input/layout:** notation and pad stay visible without performance scrolling,
   including two-bar phrases on a small iPhone. Hold one finger and tap another;
   simultaneous contacts remain separate; moves/releases add no taps. Do not
   show live red/green judgments or running score. Visual stutter must not move
   scheduled clicks. Try 30, 80, 120 and 240 BPM.
6. **Review:** score, all five counts (including zeros), original notation, then
   timeline. One bar per row; hollow target markers and solid actual tap markers
   occupy one lane. True offsets must not be exaggerated or clamped. Early first
   notes remain visible before beat 1. Cross-bar pairs may occupy different rows.
   Selecting a marker highlights both members of a match; misses/extras have no
   counterpart. Nearby-marker buttons and Inspect bar controls must make exact
   overlaps selectable. No millisecond labels or playback on review.
7. **Scoring:** play accurately, omit a note, add an extra, tap consistently late,
   and do not tap at all. Results should reflect those distinctions without
   shifting a consistent offset away or cascading one miss into later misses.
   Use automated tests—not subjective finger accuracy—to verify exact thresholds.
8. **Retry/selection:** Retry returns to preparation at the same tempo. Switch
   exercises and back; each remembers its own BPM. All four are unlocked. New
   attempts replace results. Terminate/relaunch: all tempos reset to 80 and no
   history remains. Review must always belong to the selected exercise/attempt.
9. **Cancellation:** Stop, app switching/locking, a call, or route change during
   setup, listening, count-in and performance must stop playback and produce no
   score. Starting again must work; stale delayed callbacks must not stop the new
   attempt. Backgrounding while already reviewing must preserve the current result.
   At natural attempt end, audio stops and the app briefly shows Finishing while
   draining already-occurred input across UIKit callbacks. Check delayed final-bar
   contacts are counted independent of callback order. New touches timestamped
   at/after the end never count. The bounded drain is 100 ms after observing the
   end; input delivered after that deadline is not retained. This avoids an
   immediate timer-versus-input race, not arbitrary OS stalls or lost hardware events.
   A configuration-failure notification captured before intentional audio stopping
   must still cancel even if its MainActor handler runs during the drain. Only
   engine configuration notifications timestamped at/after intentional stopping
   are suppressed there; route, interruption and media-service events are not.
10. **Diagnostics:** open only while practice is idle; close/swipe-dismiss during
    a diagnostic run and ensure audio stops. Return to practice without competing
    engines. JSON sharing remains in Diagnostics only.

## Measurement limitations

Scoring uses the unchanged monotonic touch/host-time reference, with no acoustic
offset correction. The first timing build was accepted by the user; no numerical
latency budget was independently measured. These checks do not establish identical
scoring reliability across Bluetooth and wired/speaker routes. Native build,
glyph appearance, sound balance and lifecycle behavior require fresh validation.
