# Rhythm Trainer — practice version

A native portrait iPhone rhythm-practice app with **four exercises**: steady
quarters, eighth-note pulse, rests, and offbeat entrances. Read standard percussion
notation, optionally Listen, then Start a four-beat count-in and tap the rhythm.
Review a score, five judgment counts, and a DAW-style target/tap overlay.

Tap sounds and demonstrations use a short dry snare, distinct from the metronome.
Tempos are 30–240 BPM and remembered per exercise only while the app is open.
There is no persistent history, account, cloud sync, or full curriculum yet.

The original timing harness remains available under **Diagnostics**, including
raw JSON sharing. Practice scoring is not an acoustic-latency measurement and
does not calibrate Bluetooth.

## Run on your iPhone

On a Mac with Xcode 16+ and an iOS 17+ phone:

```sh
brew install xcodegen
xcodegen generate
open RhythmTiming.xcodeproj
```

Select your signing team and a unique bundle identifier, select the connected
iPhone, and run. **Use the [Mac setup guide](docs/timing-test-device-guide.md#build-on-a-mac)
and [practice-version device checklist](docs/practice-version-validation.md).** The generated Xcode project
is ignored; `project.yml` is its source of truth. Changes made only in Xcode
may be lost on regeneration.

## Test the deterministic core

With Swift 5.9 or newer, on Linux or macOS:

```sh
swift build
swift test --filter TimingSessionTests
swift test --filter PracticeSessionTests
swift test
```

`Sources/TimingCore` contains the pure timing/practice-session models; `iOS/`
contains the SwiftUI/UIKit interface and AVFoundation audio. Core tests do **not** compile or validate
the Apple-framework integration. An iOS build and real-device testing are still
required; see [validation status](docs/practice-version-validation.md).

## Scope and planning

- [Authorized practice-version scope and decisions 49–61](docs/planning/practice-version.md)
- [Implementation issue](https://github.com/armaan-io/rhythmic/issues/2)
- [Original timing-test scope](docs/planning/timing-test-build.md)
- [Full-app interview checkpoint](docs/planning/rhythm-trainer-interview.md)

The full-app interview remains open. The 24-exercise curriculum and persistent
history are deferred; this version implements only the authorized four-exercise loop.
