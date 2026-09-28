# Timing-test validation status

Source milestone: authorized timing harness for
[issue #1](https://github.com/armaan-io/rhythmic/issues/1), not the full app.

## Checks performed in Linux

- Swift 6.2.3 with the Swift 5.9 package manifest: deterministic core builds.
- Nine XCTest cases at the agreed public timing-session boundary cover absolute
  beat scheduling and accents, tempo extremes, invalid configuration, contact
  timestamps and simultaneous contacts, invalid/out-of-run taps, stop reasons,
  completion/pre-roll cancellation, bounded diagnostics, and exported JSON.
  The final full `swift test` run passed all nine with zero failures;
  `swift build -Xswiftc -warnings-as-errors` also passed.
- New behaviors were exercised through failing tests before implementation,
  followed by focused test runs and incremental builds. Export testing also
  caught and corrected missing computed timing fields in synthesized JSON.
- Swift frontend parsing of the iOS sources checks syntax only, not Apple API
  types or availability.
- Official XcodeGen 2.46.0 was compiled on Linux and successfully generated
  `RhythmTiming.xcodeproj` from `project.yml`. Inspected source membership,
  iPhone/iOS settings, local package reference, product dependency, and shared
  scheme. Generate in the **repository root** so package path `.` resolves there.
- Git whitespace checks. Generated projects and Swift build artifacts are ignored.

## Code review

Parallel Standards and Spec reviews used the pre-implementation commit
`ff656946eca7bc4da981626c319d6699e57cebde` as the fixed baseline.

- **Standards:** no documented-rule violations or actionable smell findings.
  A correctness review found that finishing within a per-contact callback could
  drop the rest of a delayed multitouch batch. The pad now passes a complete
  batch, and the model processes it before completing the run.
- **Spec:** the same batch-boundary issue and an export-workflow mismatch were
  found. JSON now uses an in-app system share sheet instead of requiring a Files
  export followed by sharing elsewhere.
- Both axes re-reviewed the fixes with **zero outstanding findings**. The
  batch-boundary device check is included in the guide; source review does not
  replace iOS integration testing or physical timing measurements.

The Linux toolchain and its runtime dependencies were downloaded into a temporary
directory outside the repository. They are not bundled with the app and do not
change the Mac build instructions. Use a normal Swift installation for repeatable
local checks. No system-wide toolchain changes were made.

## Not yet verified — required on the Mac and iPhone

- Apple SDK typechecking/linking, Xcode simulator build, signing, and installation.
- iPhone clock alignment, audible metronome stability, touch delivery, percussion
  responsiveness, or any numeric acoustic-latency/jitter target.
- Real UIKit/SwiftUI touch/scroll behavior and overlapping finger contacts.
- Actual interruption, route-change, background, audio-engine reset, and share
  sheet behavior on iOS.
- Speaker, wired, and Bluetooth route behavior and latency-report accuracy.

No successful device build or physical timing benchmark is claimed. Follow
[the Mac/device guide](timing-test-device-guide.md) and record failures as well as
successes. The full app must not proceed solely on the strength of unit tests.

## Device run record template

For each route/tempo combination, record:

- Commit/build, Xcode version, iPhone model and iOS version.
- Output route, device volume, metronome/rhythm levels, and selected BPM.
- Completed versus cancelled run and observed stop reason.
- Metronome regularity, tap responsiveness, overlaps, and any audible anomalies.
- Whether visual stutter affected clicks, output export filename, and any
  reproducible interruption/startup issue.
- Measurement apparatus/procedure if physical timing was actually measured;
  otherwise label findings subjective rather than numerical latency evidence.
