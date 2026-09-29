# Authorized four-exercise practice version

Implementation tracker: [armaan-io/rhythmic#2](https://github.com/armaan-io/rhythmic/issues/2).

## Status and authorization

The user reported that the timing-test build passed all their checks and gave
the go-ahead for the next version. This is user-reported device validation,
not an independently measured acoustic-latency benchmark. Following questions
49–61, the user explicitly confirmed shared understanding and said "authorised".
This document supersedes timing-only authorization for the limited scope below.
The full 24-exercise product and persistent history remain deferred.

## Decisions 49–61

- **Q49:** implement one complete practice loop with four representative exercises,
  not the complete curriculum/history. The user also requested a more audible
  tap sound because the original hit was masked by the metronome.
- **Q50:** use a short, dry snare-like sound for taps and Listen demonstrations;
  retain distinct metronome clicks and separate Metronome/Rhythm volume controls.
- **Q51:** allow a pre-downbeat first-note match inside the early matching window
  only when the exercise begins with a note. Other count-in taps remain unscored.
  Opening rests get no exception. This revises Q40 of the original interview.
- **Q52:** on-time window is ±clamp(10% of a quarter beat, 25 ms, 50 ms).
  Matching window is ±min(25% of a quarter beat, 150 ms). Matched taps outside
  the on-time window are early/late. Unmatched targets are missed; unmatched
  in-attempt contacts are extra. These thresholds are provisional for device tuning.
- **Q53:** on-time matches earn 1 point. Outside the on-time window, credit falls
  linearly to 0 at the matching-window boundary. Misses earn 0. Score is
  round(100 × earned points / (target count + extra count)); no negative scores.
  Eight on-time hits score 100; seven and a miss score 88; eight plus an extra 89.
- **Q54:** match over the whole phrase, preserving chronological order and
  one-to-one mapping. First maximize matched target count, then minimize total
  absolute timing error, then prefer earlier target and earlier tap. Never shift
  the player's timestamps to improve alignment.
- **Q55:** use the four patterns in the table below. Conventional five-line
  percussion notation, notes at one position, no ties or holds. Four-bar content
  is deferred to the larger curriculum.
- **Q56:** review includes score/summary, original notation, and the independent
  proportional DAW timeline. Corresponding bar numbers do not imply identical
  horizontal spacing between notation and timeline.
- **Q57:** show all five counts, including zeros: On time, Early, Late, Missed,
  Extra. No subjective rushing/dragging messages. Selectable markers show their
  category and highlight their matched partner, if any.
- **Q58:** each exercise starts at 80 BPM, with 30–240 BPM slider/stepper controls.
  Remember each exercise's tempo only while the app is open. Retry returns to
  preparation, not an automatic count-in. Starting another attempt replaces the
  previous result. Relaunch resets tempos; no persistence/history.
- **Q59:** Listen plays once immediately with metronome, no musical count-in.
  Listen becomes Stop Listening; tempo is locked and pad silent during listening.
  Start interrupts Listen and begins a fresh four-beat count-in; audio never
  overlaps. Count-in taps sound, with only the Q51 exception assessed.
- **Q60:** approved deterministic **practice-session boundary** for tests: exercise,
  tempo, timestamped contacts and lifecycle events in; transitions, schedules,
  first-note exception, matching, score, counts and review data out. Native audio,
  UIKit touch, notation appearance and system sharing still need device checks.
- **Q61:** user explicitly authorized this scope, preserving decisions locally
  and in GitHub before implementation; use existing visual styling rather than
  expanding features. Run relevant checks and two-axis review, then commit.

| Exercise | Bars | Required taps (1-based musical beats) |
| --- | --- | --- |
| Steady quarters | 1 | 1, 2, 3, 4 |
| Eighth-note pulse | 1 | 1 & 2 & 3 & 4 & |
| Space between notes | 2 | Bar 1: 2, 4; bar 2: 1, 3 |
| Offbeat entrances | 2 | Bar 1: 1, 2&, 3, 4&; bar 2: 1&, 2, 3&, 4 |

The ampersand marks the intervening eighth-note subdivision. Rests are written
explicitly; the last exercise uses eighth rests/onsets for offbeat entrances and
quarter notes for on-beat hits. Every measure must contain exactly four beats.

## Preserved decisions and scope limits

- Portrait native iPhone, one independent-multitouch pad, onset-only assessment.
- Optional Listen → one-bar count-in → performance through the last bar → review.
- No live accuracy judgments. Separate 1–2–3–4 indicator and neutral pad feedback.
- DAW review: hollow targets and solid actual taps in the same lane; true timing
  positions, one bar per row, selectable matched pairs; no raw milliseconds shown.
- Stop/background/interruption/route changes cancel without a scored result.
  Keep Bluetooth permitted with a warning, not automatic calibration.
- No extra app accounts, networking, cloud, persisted history, rhythm generation,
  full curriculum, ties, additional meters, sixteenths, or triplets.
- Keep the diagnostic timing harness accessible for regression checks. Its export
  is engineering-only; the practice review remains visual, without playback/export.

## Implementation and validation guidance

Extend the existing platform-independent Swift package at the approved public
practice-session boundary. Keep sample/host-time audio scheduling independent of
UI redraws. Bound event storage and fail closed on overflow rather than silently
scoring an incomplete attempt. Retain raw timestamps and acknowledge output-route
latency limitations. In-attempt extras count; unmatched pre-start warm-up contacts
do not become extras. No new post-end grace is needed: the last possible eighth
onset is half a beat before the bar ends, beyond the quarter-beat matching window.

Use red/green tests for meaningful behavior, incremental typechecking and focused
test runs, then the full suite and Standards/Spec review. Linux checks cannot
establish Apple SDK compatibility, correct glyph appearance, speaker audibility,
or real input/audio timing. Re-run the Mac/iPhone checks for this changed version.
