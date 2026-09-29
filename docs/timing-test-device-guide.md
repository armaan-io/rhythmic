# Build and validate the iPhone timing harness

The current app opens the four-exercise practice version. Use **Diagnostics**
to access the original harness described here. Mac build/signing instructions
remain applicable. For the new flow use [the practice checklist](practice-version-validation.md).
The tap sample is now a dry snare shared with practice demonstrations; metronome
clicks are unchanged. Validate the new sound even if the older harness passed.

This is the authorized **timing test only**: a 16-bar accented quarter-note
metronome, an independent-multitouch percussion pad, and raw JSON diagnostics.
It has no scoring, calibration, notation, curriculum, microphone input,
networking, or practice history. A source build or passing core tests does not
establish acceptable device timing.

## Build on a Mac

Use Xcode 16 or newer, with an iOS SDK and device support compatible with your
iPhone. The app targets iOS 17+, iPhone only, portrait. Install Xcode from Apple,
open it once to install components, and select it in Xcode Settings → Locations
→ Command Line Tools. Copy or clone the entire repository to the Mac.

From the repository root:

```sh
brew install xcodegen
xcodegen generate
open RhythmTiming.xcodeproj
```

`project.yml` is the project source. XcodeGen resolves the local package at `.`;
its package manifest is named `RhythmTiming`, and the app imports its library
product `TimingCore`. Sounds are generated in memory; no audio assets are needed.
There is no microphone permission prompt. Playback uses the playback audio
session category, so the silent switch does not mute it; device volume still
applies.

1. In Xcode Settings → Accounts, add your Apple Account.
2. Select the **RhythmTiming** app target → Signing & Capabilities. Keep
   automatic signing enabled and select your Personal Team (or existing team).
3. Change the app bundle identifier to a unique identifier you control, for
   example `com.yourname.rhythmtiming`. You can put that value in
   `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and regenerate to retain it.
4. Connect and unlock the iPhone; trust the computer if prompted. Select the
   physical iPhone as the run destination for the RhythmTiming scheme.
5. Enable Settings → Privacy & Security → Developer Mode on the phone if
   prompted, then restart and confirm. Follow any device-management trust
   prompts for your developer identity.
6. Build and Run. Free personal signing may require periodic reprovisioning
   and reinstallation; follow Xcode's current signing instructions.

Generated project signing edits can be overwritten by regeneration. No team ID
or signing identity is supplied in the repository.

### Simulator build and independent core checks

With an iOS simulator runtime installed in Xcode:

```sh
xcodegen generate
xcodebuild -project RhythmTiming.xcodeproj -scheme RhythmTiming \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
swift test
```

`swift test` exercises the standalone deterministic Swift package; it does not
build UIKit or AVFoundation. Simulator builds exercise Apple SDK compilation,
but simulator audio and mouse input cannot validate iPhone timing or multitouch.
On Linux, `swiftc -frontend -parse iOS/*.swift` checks syntax only; it cannot
typecheck Apple frameworks or replace an Xcode build.

## Use the harness

Set 30–240 BPM using the slider or one-BPM stepper and press **Start**. Tempo is
locked during preparation and the run. Audio activation settles first, followed
by a 0.25-second scheduling pre-roll; this is not a musical count-in. The pad
records only from the first planned beat until the end boundary. It is silent
outside that interval. Beat 1 is accented; the separate 1–2–3–4 indicator is
display-only and may lag under UI load.

Every new finger contact creates a separate event, even if another finger is
still held down. Holds, moves and releases do not create additional taps. The
pad flashes neutrally, with no accuracy judgment. The Metronome and Rhythm
sliders independently control the clicks and pad sounds; device volume is the
master. Scroll outside the pad to reach controls on smaller phones.

Runs end after 16 bars: 128 seconds at 30 BPM, 32 at 120 BPM, and 16 at 240 BPM.
Stop ends early. Leaving the active scene (including system overlays), an audio
interruption, a route change, or an engine/media-service failure cancels the run.
There is no automatic resume. Start again for a fresh run. Startup's own audio
configuration notifications are allowed to settle before arming; interruption
and media-service failures still abort preparation.

After stopping, **Share JSON diagnostics** opens the system share sheet.
Choose a sharing destination or Save to Files. The app holds only the current
diagnostic document in memory, with no app-managed temporary export URL.
Starting again removes the previous export;
save it first if needed. Failed preparation may have no session to export.

## Real-iPhone checklist

Record the iPhone/iOS version, app build, output route, device volume, BPM, and
what you observed. Save individual exports under descriptive filenames.

- **30, 120, 240 BPM:** complete a full run at each tempo. Listen for stable
  quarter notes and one accent per four beats; confirm 16 bars and automatic
  completion, including the final beat's remaining duration.
- **Multitouch:** hold one finger down while repeatedly tapping another. Place
  two or more fingers together. Confirm each new contact increments the count
  independently. Drag or release held fingers: neither should add events.
  Confirm touches do not start scrolling the pad's parent view.
- **Boundary delivery:** when debugging delayed input at the last beat, all
  valid contacts in one delivered UIKit batch must be retained before finalizing,
  regardless of set iteration order. Contacts whose event time precedes the end
  but whose receipt follows it are logged if the run has not already finalized;
  they do not play new sounds after the boundary. Batches arriving after final
  completion are ignored. This is raw delivery diagnostics, not scoring logic.
- **Sound response:** try rapid alternating and simultaneous contacts. Listen
  for sounds backing up or unexpected gaps. Tap audio uses 16 preattached
  players, reusing the oldest on wrap rather than queuing behind old hits.
  Heavy bursts can truncate older sounds; estimated voice steals are exported.
- **Controls and load:** move both volume sliders while tapping; mute each
  independently. Scroll outside the pad. Confirm tempo stays locked and audible
  clicks remain steady even if the visual indicator stutters.
- **Early stops/retries:** stop during preparation, pre-roll, mid-run, and near
  the last beat. Repeat Start/Stop several times. Check no old clicks or tap
  sounds carry over, no stale export remains during a new run, and failed starts
  return to a usable Start button with a clear error.
- **Lifecycle:** switch apps and lock the phone during separate runs. Trigger
  an actual audio interruption (for example a phone call). Confirm cancellation,
  immediate audio shutdown, no resume, and cancelled diagnostics when a session
  existed. A system overlay may also cancel by making the scene inactive.
- **Routes:** test the built-in speaker and available wired outputs. Connect or
  disconnect headphones/Bluetooth during a run; confirm cancellation. Start
  again on the new route and confirm the reported route is correct. Where
  supported by the OS and playback category, Bluetooth A2DP, HFP and LE ports
  all trigger the warning. The app does not force HFP or request microphone use.
- **Startup notifications:** repeatedly start from idle and after changing
  routes. Normal audio-session activation should not cancel every fresh run.
  A stopped/reconfigured engine during preparation must fail clearly rather
  than silently run with mismatched audio format.
- **Export:** complete, manually stop and interrupt separate runs. Export each,
  dismiss the share sheet, retry it, then start a new run. Check the file always
  belongs to the intended run and inspect any system share-destination errors. Engine/media-service
  reset behavior requires a suitable device/debugging setup; mark untested
  cases explicitly rather than treating them as passed.

### Export invariants to inspect

- `session` contains BPM, monotonic start, 16 bars, 64 planned beats, accepted
  taps, and the final stop event. Adjacent planned beats differ by `60 / bpm`,
  and every fourth beat starting at index zero is accented.
- Accepted event times lie in `[startTime, endTime)`, with finite receipt times
  at or after their event times. Separate contacts can have identical event
  times; do not deduplicate them or assume set iteration gives chronological
  ordering for contacts delivered together.
- A completed run stops at its planned end. Other terminations are labelled
  `cancelled`, with their actual stop reason; no score is emitted. The core's
  10,000-contact limit fails closed with `capacityReached`. This is a resource
  bound, not a suggested manual device test.
- Start/stop audio snapshots contain actual output port names/types, Bluetooth
  status, sample rate, I/O buffer duration, output latency and output-node
  presentation latency. `renderedSampleRate` identifies the PCM rendering rate.
  The stop snapshot may describe the **new** route after a route cancellation.
- Initial/final volume levels are recorded; intervening slider changes are not
  a replayable volume history. The app does not read the iPhone's user-assigned
  name or an account identity, but output port names can contain personal labels
  (for example, named headphones). Inspect exported files before sharing them.

## What these diagnostics can and cannot show

The full 16-bar mono PCM buffer is rendered at the engine's actual output sample
rate, then scheduled once with `AVAudioPlayerNode` at an `AVAudioTime` host time.
Each beat's PCM onset is rounded to the nearest sample relative to that start.
The 30 Hz UI timer observes progress/end only; it does not schedule clicks.
The finite buffer bounds sound even if the main thread's end observation is late.
Tap sounds reuse fixed buffers and preattached players, with no custom render
callback doing allocations or UI work.

`UITouch.timestamp`, receipt-time system uptime, and host-time seconds share the
monotonic uptime timebase. Requested beat times are **not microphone observations
of sound leaving the speaker**. Event-to-receipt delay reflects software delivery;
event-to-beat differences also include human timing, touch processing and output
behavior. Reported output and presentation latencies may overlap: do not add or
subtract them to manufacture calibrated results. Zero reported latency is not
evidence of zero physical latency. Bluetooth can add substantial delay.

There is no automatic offset correction, user calibration or physical-latency
measurement. Device observations, an agreed measurement method and acceptance
criteria are still required before claiming timing quality or advancing to the
full app. No benchmark or device validation is asserted as passed by this guide.
