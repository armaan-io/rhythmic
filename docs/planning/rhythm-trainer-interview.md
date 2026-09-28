# Rhythm Trainer: product interview checkpoint

**Status: DRAFT — interview incomplete; implementation not authorized.**

**Subsequent scope authorization:** after saving this checkpoint, the user
explicitly confirmed and authorized the limited timing-test build in
`docs/planning/timing-test-build.md`. The status above and authorization notes
below preserve the original interview state; the full app remains unauthorized.

This document preserves the agreed product direction and all 48 answered
questions from the initial design interview. It is a decision record, not a
verbatim transcript or a finalized implementation specification. Individual
choices below are agreed, but the user has not confirmed overall shared
understanding. Do not treat this checkpoint as a ready-for-agent ticket.

The user explicitly requested that the full discussion be saved so future
sessions do not lose context. Documentation preservation is authorized;
building the app or its timing prototype is not yet authorized.

## Instructions for the next session

1. Read this entire record before asking questions or proposing implementation.
2. Continue the interview at **question 49**. Do not repeat settled questions
   unless resolving a contradiction or a newly discovered dependency.
3. Ask **one question at a time**, provide a recommended answer, and wait for
   feedback. Decisions belong to the user, including technical tradeoffs.
4. Look up discoverable facts in the filesystem, tools, or relevant primary
   documentation rather than asking the user to supply them. Do not assume
   access to the user's iPhone or friend's MacBook from this Linux workspace.
5. Resolve dependent decisions in order. Distinguish unresolved proposals from
   approved requirements; flag changes to earlier answers explicitly.
6. Keep this checkpoint current as the interview continues. Before starting
   implementation, obtain explicit confirmation of shared understanding and
   authorization to proceed.
7. Final PRDs and implementation tickets belong in GitHub Issues for
   `armaan-io/rhythmic`, following `docs/agents/issue-tracker.md`. This local
   interview checkpoint does not change that convention. Do not publish it as
   approved or apply `ready-for-agent` while the interview remains incomplete.

## Product intent

An iPhone rhythm-training app for people who can already read basic musical
notation but want to perform rhythms more accurately. The app presents a
prescribed rhythm; the player taps it on one large pad while a metronome keeps
time. This is not primarily a tap-to-set-tempo app or a rhythm-memory game.

The initial deliverable is a personal prototype for the user's own iPhone,
not an App Store release or TestFlight beta. Use native Swift/SwiftUI with
dedicated touch handling and low-latency audio. Validate a minimal timing test
on a real iPhone before building the full prototype.

## Current end-to-end experience

1. Browse an unlocked, skill-grouped curriculum with a recommended order.
2. Select an exercise; view conventionally engraved percussion notation.
3. Adjust its suggested tempo using a slider and plus/minus controls.
4. Optionally press **Listen**: immediately play the full pattern once over the
   metronome at the selected tempo, without a count-in and without scoring.
5. Press **Start**: play one bar of count-in, showing 1, 2, 3, 4, then begin the
   scored phrase. There is no mandatory demonstration before an attempt.
6. Tap the large pad. Each new finger contact makes a percussion sound. The
   metronome continues, but the target rhythm does not play during performance.
7. During performance, show notation, a separate 1–2–3–4 beat indicator, and a
   neutral pad response. Do not show live accuracy judgments or a running score.
8. Continue through the end of the final bar, including trailing rests. Stop
   automatically and show the review.
9. Review a 0–100 score, factual timing summary, and DAW-style target/tap overlay.
   The review is visual only. Retry or return to exercise selection; exact
   navigation and button arrangement remain undecided.
10. Persist a local summary of the completed attempt, not its detailed timeline.

## Complete question and decision ledger

### Core task, input, and audience

### Q01 — What does the player reproduce? — B

Reproduce a prescribed rhythm containing notes and rests against a steady
metronome. Do not limit the core task to tapping every metronome click. Do not
remove the metronome to turn the attempt into a memory-only exercise.

### Q02 — How is the pattern presented? — B

Provide an audible demonstration and **standard music notation**, not a
simplified beat grid. Notation remains available during the attempt. Q20 later
establishes that hearing the demonstration is optional and separately invoked.

### Q03 — What is the attempt structure? — A, later revised by Q20

Use discrete attempts and a review screen, not continuous practice loops or
alternating call-and-response without a result screen. The original choice was
demonstration → count-in → performance → review. Q20 supersedes only the
mandatory demonstration: the current flow is optional Listen, then
Start → count-in → performance → review.

### Q04 — What remains audible during performance? — B

Play the metronome and a percussion sound for every pad tap. Stop playing the
target pattern during the scored performance. Tap-triggered audio must be
responsive enough to help rather than interfere with timing.

### Q05 — What does the player tap? — A

One large on-screen pad. All notes represent the same percussion hit. Either
hand can play; do not assess hand choice, pitch, or instrument selection.

### Q06 — Are note durations held? — A

Assess note onsets only, like percussion. A contact triggers a short hit; neither
finger hold duration nor release timing is scored. Longer values and rests
determine the spacing before the next required onset. Extra taps in those
spaces count as errors.

### Q07 — Who is the initial audience? — B

People who understand basic notes and rests but need rhythm practice. Do not
assume a complete beginner requiring notation lessons, or prioritize advanced
musicians' analysis tools over foundational practice.

### Curriculum, feedback, and progression

### Q08 — Where do patterns come from? — A

Use curated built-in exercises with deliberate progression. Do not include
random generation or player-authored patterns in the first version.

### Q09 — How broad is the curriculum? — A

Stay in 4/4. Cover quarter notes, eighth notes, quarter/eighth rests, and simple
syncopation. Introduce foundational paired eighth notes and then offbeat
patterns. Exclude sixteenth notes, triplets, and other time signatures initially.
Q26 excludes ties. Exact exercise notation has not yet been authored or approved.

### Q10 — How long are exercises? — C

Progress from one-bar exercises to two- and four-bar phrases as difficulty
increases. Do not make every exercise the same length. The exact distribution
of lengths across the curriculum is undecided.

### Q11 — Who controls tempo? — B

Each exercise has a suggested starting tempo that the player can adjust before
an attempt. Hold the selected tempo constant during that attempt's count-in and
performance; demonstrations use the selected tempo too. No adaptive tempo.

### Q12 — What feedback follows an attempt? — B

Show an overall accuracy score and a timing breakdown identifying on-time,
early, late, missed, and extra taps. Do not add per-tap millisecond readouts or
advanced timing statistics in the first version. Q34's accompanying correction
and Q35–Q37 define the final visualization instead of the earlier
notation-aligned proposal.

### Q13 — Are accuracy judgments shown live? — A, visual guide revised by Q34

Save all accuracy judgments for review. During performance, show a neutral pad
response and an orientation guide, without red/green judgments or a running
score. Q34 replaces the originally suggested moving notation cursor with a
separate beat indicator.

### Q14 — Does performance gate exercises? — A

Keep all exercises unlocked. Provide a recommended order and progress
information, but do not require a score or completion to access later material.

### Q15 — How strict is timing assessment? — A

Use one balanced, moderately forgiving standard. Timing windows should scale
with tempo within sensible limits; do not secretly tighten scoring for later
exercises. No player-selectable strictness modes. Exact thresholds remain
unresolved and require playtesting.

### Q16 — What does accuracy reward? — A

Combine timing precision, misses, and extras in one score. A matched tap earns
less credit as its timing error grows. Small timing errors should cost less
than misses. Extra taps reduce the score. The exact formula and penalty weights
are not yet decided.

### Q17 — What progress persists? — B

Store progress locally on the device, including attempted exercises, scores,
and tempos. Best results must distinguish practised tempos rather than silently
comparing a slow attempt to a faster one as equivalent. No account or cloud sync.
Q43 specifies summary history without retained detailed timelines.

### Device scope, audio routes, and preparation

### Q18 — Which devices and orientations? — A

Target iPhone in portrait orientation only. Keep performance notation visible
without scrolling; four-bar phrases may use two lines. No dedicated iPad layout
or landscape mode in the initial scope.

### Q19 — Is Bluetooth allowed? — B

Allow Bluetooth with a clear warning that wireless output may delay tap sounds
and affect timing judgments. Do not block the attempt solely because Bluetooth
is connected. No Bluetooth calibration flow in the first version. Speaker and
wired-headphone timing still require device validation; this decision is not
a claim that all outputs have equal latency or scoring reliability.

### Q20 — What happens when starting or retrying? — C

Provide a separate **Listen** action. **Start** goes directly to the count-in;
do not force a demonstration on the first attempt or on retries. This overrides
Q03's mandatory listening phase. Q44 defines Listen's playback behavior.

### Q21 — How long is the count-in? — A

One bar: four quarter-note clicks at the selected tempo with a visual
1, 2, 3, 4. Performance starts on the next downbeat, including when the exercise
begins with a rest. No selectable count-in length initially.

### Q22 — What does the metronome play? — A

Quarter-note clicks with a distinct accent on beat 1 of every 4/4 bar. No
eighth-note subdivision option. The player supplies subdivisions between clicks.

### Review, library, notation, and tempo controls

### Q23 — Can players hear their result? — A

Visual review only. Do not provide target playback, reconstructed attempt
playback, or overlaid audio comparison on the result screen. Listen remains
available in the pre-attempt flow for subsequent practice.

### Q24 — How is the library organized? — A

Skill-based groups, ordered from simpler to harder: quarter-note timing,
eighth-note subdivisions, rests, and simple syncopation. Prefer shorter phrases
before longer ones within progression. All groups remain accessible. No
filter-based library or anonymous numbered-only sequence as the primary model.

### Q25 — How many initial exercises? — B

Twenty-four curated exercises: four skill groups with six exercises each.
Later groups may reuse earlier concepts. Exact patterns and suggested tempos
remain to be specified.

### Q26 — Are ties included? — A

No ties. Every notehead corresponds to a required tap. Use notes and rests to
create offbeat patterns; defer tied-note reading to a later curriculum.

### Q27 — How is unpitched notation displayed? — B

A five-line percussion staff, a percussion clef, and all notes at the same
staff position. Preserve standard rhythmic note values, rests, barlines, and
the 4/4 time signature. The exact staff position and engraving implementation
have not been selected.

### Q28 — What tempo range? — C

30–240 BPM, adjustable in 1-BPM increments. Each exercise has a suggested tempo.
Do not silently narrow the approved range to the earlier recommendation of
40–160 BPM. Timing and layout behavior must account for both extremes.

### Q29 — How is tempo set? — A

A numeric BPM display, slider for larger changes, and plus/minus buttons for
1-BPM adjustments. No separate tap-tempo control in the first version, despite
the original comparison to metronome apps.

### Q30 — What happens on interruption? — A

Cancel an interrupted attempt and do not save a score. A new attempt starts
from the beginning with a fresh count-in. This includes app switching, locking
the phone, calls, and audio-output changes. Preserve already completed results.
Do not pause/resume midway through a phrase or continue scored background play.

### Q31 — Can finger contacts overlap? — A

Count each new finger contact independently, even while another finger remains
on the pad. Holding or sliding generates no further taps. Simultaneous contacts
count as separate taps; an accidental double hit may therefore be an extra.
Do not require complete release of the pad between hits.

### Q32 — Where are timing errors visualized? — A, superseded in part at Q34

Originally selected intact notation with a timing strip directly beneath it,
including symbols or labels rather than color alone. The later user-authored
DAW timeline proposal replaces the requirement to align feedback horizontally
with engraved notes. Preserve understandable missed/extra/early/late feedback
and do not depend on color alone.

### Q33 — Should notation use proportional spacing? — B, clarified at Q34

Use conventional music engraving, not evenly spaced notation forced onto a
linear time grid. Feedback uses its own proportional time axis. In the next
answer the user explicitly proposed a DAW-like review sheet: bars subdivided
into beats, with correct and played patterns overlapping. That proposal is the
current review direction, not a notation-aligned timing strip.

### Q34 — What guides performance visually? — C, plus Q33 correction

Show a separate 1–2–3–4 beat indicator above the staff, without an in-staff
cursor or beat-region highlight. This supersedes Q13's moving-cursor suggestion.

In this same response, the user requested a **DAW-style review timeline** with
bars subdivided into beats and target/actual patterns overlaid. Review uses a
proportional time grid; performance uses conventional notation. Whether review
also retains a separate copy of the notation is not explicitly settled.

### Q35 — How are target and actual taps distinguished? — A

Hollow target-onset markers and solid actual-tap markers in contrasting colors,
overlaid in one lane on the same time axis. An exactly timed tap fills its target;
early/late taps appear left/right. Misses leave a hollow target; extras have no
matched target. Shape differences must work without relying on color alone.
Use onset markers, not note-length blocks suggesting held input duration.

### Q36 — How does the review fit longer phrases? — A

One bar per row, consistent row widths and beat subdivisions, clear bar labels,
and vertical scrolling if needed. Do not use a single horizontally scrolling
DAW strip or a pinch-to-zoom overview in the first version.

### Q37 — Are timing offsets exaggerated? — A

Preserve actual proportional timing positions. Let the player select a target
or actual-tap marker to see its judgment (for example, On time, Early, or Late).
Selecting either member of a matched pair highlights both. Do not exaggerate
offsets or introduce millisecond readouts. Close and overlapping marker
selection needs design attention, especially at slow tempos.

### Matching, boundaries, scoring, and history

### Q38 — Is a consistent player offset corrected? — A

Judge alignment to the metronome. Do not shift the attempt to fit the target or
erase a player's consistent early/late tendency. Account for measurable
device/audio timing in the implementation without confusing that with
performance alignment. The measurement and compensation approach remains open.

### Q39 — How are taps matched to target notes? — A

Use chronological, one-to-one, error-tolerant matching against nearby onsets,
allowing unmatched targets and taps. Within a bounded timing window, seek
matches that minimize phrase timing error rather than blindly pairing by index.
A missed or extra tap must not cascade into false errors for the rest of the
phrase. Exact algorithm, window limits, tie-breakers, and ambiguity rules are
not yet decided.

### Q40 — What happens to count-in taps? — A

Count-in taps make the normal percussion sound but are excluded from scoring.
Scoring begins at the exercise's first downbeat. If the phrase begins with a
rest, taps during that scored rest are extras. The interaction between this
strict start boundary and an early first-note tap remains to be clarified.

### Q41 — When does the attempt finish? — A

At the end of the final written bar, including trailing rests. Keep the
metronome and scoring active through the full phrase, then stop and show review
automatically. An extra tap after the last note but before the phrase ends is
an error. No early finish immediately after the last expected note.

### Q42 — How is the score presented? — A

A 0–100 score plus a factual summary such as "Mostly on time · 2 late · 1 missed
· 1 extra," and the detailed timeline. No stars, grades, pass/fail threshold,
or subjective achievement labels. Exact summary wording and score rounding
are not decided.

### Q43 — How much history is retained? — A

A local chronological log of completed attempts: exercise, date, tempo, score,
and error counts. Past summaries can be browsed. Detailed tap timings and
timelines are only for the current result, not a replayable archive. Retain
Q17's distinction between best results at different tempos. Retention limits,
deletion controls, and navigation are not yet specified.

### Q44 — What does Listen play? — B

Immediately play the entire pattern once with the metronome, with no count-in.
Use the same percussion sound as pad taps, distinct from metronome clicks.
Keep notation visible and run the beat indicator. Listening is not scored and
does not loop automatically. Count-in remains mandatory for Start, not Listen.

### Q45 — What audio controls exist? — A

Two settings sliders: **Metronome** and **Rhythm**. Rhythm controls both
demonstration notes and player tap sounds. Device volume remains the master.
Use a fixed metronome sound and a fixed percussion sound, not a sound library
or user-selected instruments. Exact samples, defaults, and mute behavior are
not selected.

### Delivery and the first milestone

### Q46 — What is the first distribution milestone? — A

A personal prototype on the user's own iPhone, not TestFlight or public App
Store release. Do not introduce store assets or tester-distribution work as
requirements for the initial milestone.

### Q47 — What implementation approach? — A, with a MacBook question

Native iOS using Swift/SwiftUI, dedicated touch handling, and low-latency audio.
Keep audio scheduling and tap timestamps independent of UI animation timing.
Specific audio APIs, module boundaries, persistence technology, minimum iOS
version, and notation renderer are not yet selected.

The user said a friend has a MacBook and asked whether it can build the app.
Answer given: yes, provided it can run Xcode compatible with the user's iPhone
and iOS version. Develop source here, open the project on the Mac, configure
signing, connect the phone, enable Developer Mode if prompted, and build/run.

A free Apple Account generally supports personal device signing, typically with
seven-day provisioning requiring reinstallation. Paid membership is not yet
required or chosen. Verify current Apple requirements before providing exact
build instructions. Mac model, macOS/Xcode versions, iPhone/iOS version, account
setup, and access arrangements have not been verified.

### Q48 — Should device timing validation come first? — A

Yes. Before the full app, build a minimal metronome and tapping pad that records
timing, then use the friend's MacBook to build and test on the user's real
iPhone. Validate responsiveness and trustworthy measurements before investing
in the full curriculum, notation, and review UI. This is the chosen sequence,
not permission to begin implementation now.

The user added that the entire specification must be saved so future sessions
retain context. This checkpoint and the root agent-instructions pointer fulfill
that preservation request. Exact timing-test scope and pass criteria remain
unresolved.

## Supersession map: do not revive these earlier suggestions

| Earlier choice or suggestion | Current decision |
| --- | --- |
| Q03: mandatory demonstration before every attempt | Q20: optional separate Listen; Start goes straight to count-in |
| Q13: moving cursor during performance | Q34: separate 1–2–3–4 indicator, no cursor inside notation |
| Q32: timing strip directly aligned with notation | User correction at Q34, then Q35–Q37: independent DAW-style proportional review timeline |
| Q33 discussion of proportionally spaced notes | Conventional engraving for notation; only review uses a linear time grid |
| Recommended 40–160 BPM | Q28: user selected 30–240 BPM |
| Recommended TestFlight first milestone | Q46: user selected a personal prototype |
| Automatic demonstration count-in | Q44: Listen starts immediately; Q21's count-in applies to scored attempts |

## First milestone and validation status

### Agreed direction

- First milestone is a minimal real-device timing test: metronome, tap pad,
  tap-triggered percussion, and recorded timing.
- Use the friend's MacBook to build and the user's iPhone to assess real audio
  and touch behavior. A simulator alone cannot establish timing reliability.
- Build the full personal prototype only after validating the timing foundation.
- The current development environment is Linux and cannot run Xcode or an iOS
  device build locally. No app, timing engine, device build, or timing measurement
  has been produced as part of this interview.

### Proposed validation topics — not yet approved acceptance criteria

- Define a shared clock and observable timing behavior before selecting exact
  audio/input APIs. Distinguish scheduled audio time, audible output time, touch
  event time, and UI update time.
- Exercise tempo extremes, phrase boundaries, multiple fingers, misses, extras,
  opening/trailing rests, and interrupted attempts.
- Test matching and scoring through externally observable attempt results with
  deterministic timestamp inputs; avoid tests coupled to private implementation.
- Check real-device speaker and wired routes; investigate Bluetooth warnings
  without claiming unmeasured latency correction.
- Validate responsive tap sounds and metronome stability under realistic UI load.
- The specific test seams, hardware measurement method, latency/jitter budgets,
  and criteria to advance to the full prototype need user agreement. There is
  currently no application test suite or prior implementation to reuse.

## Open decision branches for continuing the interview

These are a planning queue, not a set of approved features or questions to ask
all at once. Prioritize prerequisites of the timing milestone, then resolve
the remaining full-product details. Begin numbering at Q49.

### Timing milestone and build feasibility

- Exact minimum timing-test capabilities and objective/subjective pass criteria.
- Device and Mac compatibility, access to signing/builds, and practical frequency
  of device testing. Inspect accessible tools/devices first; do not invent facts.
- Minimum supported iOS version and selected APIs after compatibility checks.
- How to measure output/input latency and jitter; what can be compensated
  reliably without masking the player's own timing offset.
- What happens if timing validation fails, or Bluetooth data is not comparable
  to speaker/wired results.

### Assessment semantics

- Numeric matching windows, tempo scaling limits, and the on-time threshold.
- Combined score formula, penalties, rounding, and zero-tap/extra-heavy cases.
- Matching tie-breakers at fast tempos and adjacent-note ambiguity.
- Whether a slightly early first-note tap during count-in is always excluded,
  or receives a boundary exception. Do not silently override Q40.
- Handling final-boundary taps and taps near bar boundaries in the row-based
  review, without changing the final-bar duration agreed in Q41.
- Whether Bluetooth attempts use the same saved-best comparison grouping as
  other routes; no route-specific grouping has been approved yet.

### Curriculum and notation

- Author the 24 exact patterns and suggested tempos; decide phrase-length
  distribution, group names, exercise names, and descriptions.
- Resolve how the first quarter-note group obtains variation within approved
  vocabulary; do not add half notes, whole notes, ties, or other values silently.
- Select the exact staff position, engraving rules, renderer, and small-screen
  layout while keeping performance notation fully visible.

### Interaction and review

- Exact screen flow, retry/next/back behavior, default exercise selection, and
  whether selected tempo persists per exercise.
- Stop/cancel controls, interaction while Listen is playing, and whether the pad
  sounds outside count-in/performance. These are not yet specified.
- Review timeline subdivisions, marker selection when hits overlap, boundary
  marker placement, and representation of matched versus extra taps.
- Whether review includes a separate notation reference in addition to the DAW
  timeline; the earlier alignment requirement is superseded.
- Practice-history navigation, retention limits, deletion/reset behavior, and
  any progress summary beyond the agreed per-tempo bests and attempt log.

### Remaining product and technical scope

- Visual design, app display name, onboarding, accessibility, text scaling,
  light/dark appearance, haptics, and localization. None are selected yet.
- Exact sound choices/default levels and silent-switch/audio-session behavior.
- Offline behavior, analytics/crash reporting, privacy, and whether any runtime
  networking is needed. Local storage and no accounts are agreed; additional
  policies must not be assumed.
- Persistence format, project tooling, notation dependencies and licenses, and
  concrete module/testing seams remain unselected.
- Monetization and public release plans are not decided and are not prerequisites
  for the agreed personal-prototype milestone.

## Explicitly excluded from the initial scope

- Tap-to-set-tempo as a feature; generated or user-authored exercises.
- Multiple instruments/pads, hand-choice assessment, note holds, release scoring.
- Sixteenth notes, triplets, other meters, and ties.
- Mandatory demonstrations, continuous practice loops, and live accuracy scores.
- Locked progression, selectable strictness, adaptive tempo, grades, or stars.
- Detailed numerical timing statistics or review audio playback.
- Detailed historical tap timelines, accounts, and cloud sync.
- iPad-specific layouts and landscape orientation.
- Bluetooth calibration or a Bluetooth prohibition.
- Mid-phrase resume after interruption, subdivision metronome clicks, and
  configurable count-in length.
- Public App Store or TestFlight distribution for the first milestone.

## Repository and handoff context

At this checkpoint the repository contains engineering-skill configuration and
this planning record, not application code. The configured remote is
`git@github.com:armaan-io/rhythmic.git`; the GitHub repository was created public
with Issues enabled during setup. These are setup-time facts, not a substitute
for inspecting Git status and remote state in future sessions.

Saving or committing this record locally does not upload it to GitHub. Never
push without explicit user permission. Read the root instructions for the
current version-control workflow before committing or proposing a push.

Suggested resume request:

> Read AGENTS.md and docs/planning/rhythm-trainer-interview.md. Continue the
> interview from question 49, one question at a time with your recommendation.
> Do not implement anything until I confirm shared understanding.
