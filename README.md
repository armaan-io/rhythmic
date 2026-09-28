# Rhythm Timing

A native iPhone **timing-test harness**, not the complete rhythm-training app.
Use it to try an accented metronome and independent-multitouch percussion pad,
then export raw timing diagnostics. No scoring or latency calibration is implied.

## Run on your iPhone

On a Mac with Xcode 16+ and an iOS 17+ phone:

```sh
brew install xcodegen
xcodegen generate
open RhythmTiming.xcodeproj
```

Select your signing team and a unique bundle identifier, select the connected
iPhone, and run. **The complete instructions and device checklist are in
[the device guide](docs/timing-test-device-guide.md).** The generated Xcode project
is ignored; `project.yml` is its source of truth. Changes made only in Xcode
may be lost on regeneration.

## Test the deterministic core

With Swift 5.9 or newer, on Linux or macOS:

```sh
swift build
swift test --filter TimingSessionTests
swift test
```

`Sources/TimingCore` contains the pure timing-session model; `iOS/` contains the
SwiftUI/UIKit and AVFoundation harness. Core tests do **not** compile or validate
the Apple-framework integration. An iOS build and real-device testing are still
required; see [validation status](docs/timing-test-validation.md).

## Scope and planning

- [Authorized timing-test scope](docs/planning/timing-test-build.md)
- [Implementation issue](https://github.com/armaan-io/rhythmic/issues/1)
- [Full-app interview checkpoint](docs/planning/rhythm-trainer-interview.md)

The full-app interview remains open. Its curriculum, notation, scoring, history,
and DAW-style review are **not implemented** in this diagnostic build.
