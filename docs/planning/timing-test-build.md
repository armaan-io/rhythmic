# Authorized timing-test build

Tracker: [armaan-io/rhythmic#1](https://github.com/armaan-io/rhythmic/issues/1).

## Authorization and scope

After the 48-question interview, the user explicitly confirmed shared
understanding and authorized **this timing-test scope only**. The full product
interview remains open. The older interview checkpoint describes historical
authorization state and must be read with this update.

- Native portrait iPhone harness, 30–240 BPM controls.
- Quarter-note metronome with an accent every four beats.
- Large independent-multitouch pad with immediate percussion sounds.
- Start/stop and a separate beat indicator.
- Record input timestamps against scheduled metronome times and export
  engineering diagnostics; no score or claim of measured physical audio latency.
- Cancel on backgrounding, audio interruptions, and output-route changes.
- Permit Bluetooth with a warning.
- No curriculum, music-notation renderer, scoring, history, or DAW review.
- Supply Mac/Xcode instructions and a real-iPhone validation procedure.

## Agreed automated-test seam

The deterministic timing session: given tempo, absolute monotonic start time,
touch event/receipt timestamps, and stop/interruption events, observe the beat
schedule and recorded events. Use red/green tests at this public boundary.
Hardware audio and touch responsiveness cannot be established by these tests.

## Implementation choices for the harness

These are reversible engineering choices, not new full-app product decisions:

- Swift package for the platform-independent core; iOS 17+ SwiftUI/UIKit app.
- Generate the Xcode project with XcodeGen; configure signing locally on the Mac.
- Each run lasts at most 16 bars (16–128 seconds over the supported tempo range),
  or ends earlier on Stop/interruption. This bounds audio/log memory and permits
  scheduling a complete metronome buffer ahead of time without UI timers.
- Raw touch event and receipt timestamps share the system-uptime clock with
  host-time scheduling. Report requested scheduling and system-reported audio
  latency separately; neither is a physical acoustic measurement.
- Export JSON through the share sheet, with run configuration, planned beats,
  accepted taps, end reason, and audio-route diagnostics. No network service,
  microphone recording, analytics, or persistent practice history.
- Diagnostic timing data is intentionally more detailed than the eventual
  consumer-facing review. Do not infer approved score thresholds from it.

## Completion versus device validation

Source implementation and deterministic tests are one milestone. A successful
Xcode build and device observations are a separate, required validation step.
Do not declare timing performance acceptable solely because unit tests pass.
Advance to the full app only after device testing and further user authorization.
