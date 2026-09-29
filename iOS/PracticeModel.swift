import AVFoundation
import Combine
import Foundation
import TimingCore
import UIKit

/// Native lifecycle and presentation adapter. Timing, contact eligibility and
/// assessment belong exclusively to PracticeSession.
@MainActor
final class PracticeModel: ObservableObject {
    @Published private(set) var exercise = Exercise.catalog[0]
    @Published private(set) var bpm = 80
    @Published private(set) var phase: PracticePhase = .ready
    @Published private(set) var busy = false
    @Published private(set) var beat: Int?
    @Published private(set) var bar = 0
    @Published private(set) var result: PracticeResult?
    @Published private(set) var snapshot: AudioSnapshot?
    @Published private(set) var message = "Ready"
    @Published var metronomeVolume: Double { didSet { updateVolumes() } }
    @Published var rhythmVolume: Double { didSet { updateVolumes() } }
    @Published private(set) var bluetoothConnected = false
    @Published var errorMessage: String?

    private var tempos: [String: Int] = [:]
    private var session: PracticeSession?
    private var audio: TimingAudio?
    private var startup: Task<Void, Never>?
    private var displayTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    private var armedAt = Double.infinity
    private var drainUntil: Double?
    private var intentionalPlaybackStopAt: Double?
    private let defaults: UserDefaults
    private var routeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func volume(_ key: String) -> Double {
            guard let value = defaults.object(forKey: key) as? Double, value.isFinite else { return 0.7 }
            return min(1, max(0, value))
        }
        metronomeVolume = volume("metronomeVolume")
        rhythmVolume = volume("rhythmVolume")
        refreshRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshRoute() }
        }
    }

    deinit {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }

    private func refreshRoute() {
        bluetoothConnected = AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType)
        }
    }

    func select(_ exercise: Exercise) {
        guard !busy, Exercise.catalog.contains(exercise) else { return }
        self.exercise = exercise
        bpm = tempos[exercise.id] ?? 80
        retry()
    }

    func setBPM(_ bpm: Int) {
        guard !busy else { return }
        self.bpm = min(240, max(30, bpm))
        tempos[exercise.id] = self.bpm
    }

    func listen() {
        if busy && phase == .listening { cancel(); return }
        guard !busy else { return }
        begin(listening: true)
    }

    func start() {
        guard !busy || phase == .listening else { return }
        begin(listening: false)
    }

    func cancel() {
        guard busy else { return }
        cancel(reason: .manual)
        session?.reset()
        phase = .ready
        message = "Ready"
    }

    func retry() {
        stopAudio()
        session = nil
        result = nil
        phase = .ready
        busy = false
        beat = nil
        bar = 0
        errorMessage = nil
        message = "Ready"
    }

    func leaveActiveScene() {
        // A published completed result survives scene changes.
        if busy { cancel(reason: .backgrounded) }
    }

    func tap(contacts: [PadContact]) -> Bool {
        guard busy, phase == .countIn || phase == .performing,
              let end = session?.audioPlan?.metronome.endTime else { return false }
        if let deadline = drainUntil {
            guard ProcessInfo.processInfo.systemUptime <= deadline else {
                observeTime()
                return false
            }
        } else if audio?.isHealthy != true {
            fail("Audio engine stopped or changed format. Try again.")
            return false
        }
        var acceptedAny = false
        // Do not advance inside this loop: the entire UIKit batch, including
        // simultaneous and overlapping contacts, reaches core before completion.
        for contact in contacts {
            let accepted = session?.recordContact(eventTime: contact.eventTime,
                                                   receivedTime: contact.receivedTime) ?? false
            acceptedAny = acceptedAny || accepted
            let now = ProcessInfo.processInfo.systemUptime
            if accepted && now < end && contact.receivedTime < end {
                audio?.playHit(now: now)
            }
        }
        if session?.phase == .cancelled {
            cancel(reason: session?.cancellationReason ?? .capacityReached)
            return false
        }
        observeTime()
        return acceptedAny
    }

    private func begin(listening: Bool) {
        // Invalidate even a pending Listen preparation before creating fresh audio.
        stopAudio()
        session = nil
        if !listening { result = nil }
        errorMessage = nil
        snapshot = nil
        beat = nil
        bar = 0
        busy = true
        phase = listening ? .listening : .countIn
        message = "Preparing audio…"
        guard UIApplication.shared.applicationState == .active else {
            cancel(reason: .backgrounded)
            return
        }
        let token = generation
        let audio = TimingAudio()
        self.audio = audio
        observe(audio: audio, token: token)
        do {
            try audio.prepare(metronomeVolume: Float(metronomeVolume), rhythmVolume: Float(rhythmVolume))
            var template = try PracticeSession(exercise: exercise, bpm: bpm)
            if listening { try template.listen(at: 0) } else { try template.start(at: 0) }
            guard let plan = template.audioPlan else { throw TimingAudio.Failure.buffer }
            try audio.render(plan: plan)
        } catch {
            fail("Unable to prepare audio: \(error.localizedDescription)")
            return
        }
        let preparedRoute = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.uid }
        // Drain activation notifications. Fatal lifecycle events still invalidate
        // the token; format/engine and route are checked again before arming.
        startup = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard let self, !Task.isCancelled, self.busy, self.generation == token else { return }
            guard UIApplication.shared.applicationState == .active else {
                self.cancel(reason: .backgrounded)
                return
            }
            guard preparedRoute == AVAudioSession.sharedInstance().currentRoute.outputs.map({ $0.uid }) else {
                self.cancel(reason: .routeChanged)
                return
            }
            do {
                // All PCM work is complete. Only a small pure schedule is built
                // inside this pre-roll; schedule() also enforces >50 ms remaining.
                let now = ProcessInfo.processInfo.systemUptime
                var current = try PracticeSession(exercise: self.exercise, bpm: self.bpm)
                if listening { try current.listen(at: now + 0.25) }
                else { try current.start(at: now + 0.25) }
                guard let plan = current.audioPlan else { throw TimingAudio.Failure.buffer }
                self.armedAt = now
                try audio.schedule(session: plan.metronome)
                self.session = current
                self.snapshot = AudioSnapshot.capture(engine: audio.engine)
                self.phase = current.phase
                self.message = listening ? "Listening…" : "Count in — four beats"
                self.startup = nil
                let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.observeTime()
                    }
                }
                self.displayTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            } catch {
                self.fail("Unable to start audio: \(error.localizedDescription)")
            }
        }
    }

    private func observeTime() {
        guard busy, let plan = session?.audioPlan else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let deadline = drainUntil {
            if now >= deadline { completePlayback(at: now) }
            return
        }
        guard audio?.isHealthy == true else {
            fail("Audio engine stopped or changed format. Try again.")
            return
        }
        if now >= plan.metronome.endTime {
            if phase == .listening {
                completePlayback(at: now)
            } else {
                // Sound and event eligibility end at the original bar boundary.
                // Give pending UIKit deliveries 100 ms after end observation to
                // drain across callbacks before sealing the score. This is NOT
                // extra playing time or a wider note-matching window.
                drainUntil = now + 0.1
                session?.advance(to: now, finalize: false)
                phase = session?.phase ?? .cancelled
                beat = nil
                message = "Finishing…"
                if let audio {
                    snapshot = AudioSnapshot.capture(engine: audio.engine)
                    intentionalPlaybackStopAt = ProcessInfo.processInfo.systemUptime
                    audio.stopPlayback()
                }
            }
            return
        }
        session?.advance(to: now)
        phase = session?.phase ?? .cancelled
        guard now >= plan.metronome.startTime else { return }
        let index = min(plan.metronome.beats.count - 1,
                        Int((now - plan.metronome.startTime) / plan.metronome.beatInterval))
        beat = index % 4 + 1
        // Count-in has no exercise bar number; performance starts again at bar 1.
        bar = phase == .countIn ? 0 : index / 4 + (phase == .performing ? 0 : 1)
        switch phase {
        case .countIn: message = "Count in — \(beat ?? 1)"
        case .performing: message = "Playing — bar \(bar) of \(exercise.barCount)"
        case .listening: message = "Listening — bar \(bar) of \(exercise.barCount)"
        default: break
        }
    }

    private func completePlayback(at time: Double) {
        // Stop every player before core performs whole-phrase assessment.
        stopAudio()
        session?.advance(to: time)
        if session?.phase == .review { result = session?.result }
        phase = session?.phase ?? .cancelled
        busy = false
        beat = nil
        bar = 0
        message = phase == .review ? "Attempt complete" : "Ready"
    }

    private func cancel(reason: StopReason) {
        guard busy else { return }
        stopAudio()
        session?.cancel(reason: reason)
        busy = false
        phase = .cancelled
        beat = nil
        bar = 0
        switch reason {
        case .manual: message = "Ready"
        case .backgrounded: message = "Practice stopped when you left the app. Start again when ready."
        case .interrupted: message = "Practice was interrupted. Start again when ready."
        case .routeChanged: message = "Practice stopped because the audio output changed. Start again when ready."
        default: message = "Practice stopped before it could finish. No score was recorded. Please try again."
        }
    }

    private func fail(_ message: String) {
        cancel(reason: .audioFailure)
        errorMessage = message
    }

    private func stopAudio() {
        drainUntil = nil
        intentionalPlaybackStopAt = nil
        generation = UUID()
        armedAt = .infinity
        startup?.cancel()
        startup = nil
        displayTimer?.invalidate()
        displayTimer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if let audio {
            snapshot = AudioSnapshot.capture(engine: audio.engine)
            audio.shutdown()
        }
        audio = nil
    }

    private func updateVolumes() {
        defaults.set(metronomeVolume, forKey: "metronomeVolume")
        defaults.set(rhythmVolume, forKey: "rhythmVolume")
        audio?.setVolumes(metronome: Float(metronomeVolume), rhythm: Float(rhythmVolume))
    }

    private func observe(audio: TimingAudio, token: UUID) {
        let center = NotificationCenter.default
        func add(_ name: Notification.Name, object: AnyObject? = nil,
                 reason: StopReason, startupFatal: Bool = true) {
            observers.append(center.addObserver(forName: name, object: object, queue: nil) { [weak self] note in
                let time = ProcessInfo.processInfo.systemUptime
                // Our playback-category activation may announce its own route
                // change. Actual device arrivals/removals cancel even in setup.
                let routeReason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                let activationRouteChange = name == AVAudioSession.routeChangeNotification
                    && routeReason == AVAudioSession.RouteChangeReason.categoryChange.rawValue
                let fatalDuringStartup = startupFatal && !activationRouteChange
                if name == AVAudioSession.interruptionNotification {
                    let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                    guard type != AVAudioSession.InterruptionType.ended.rawValue else { return }
                }
                Task { @MainActor [weak self] in
                    guard let self, self.busy, self.generation == token,
                           fatalDuringStartup || time >= self.armedAt else { return }
                    // Our intentional shutdown while draining may notify an
                    // engine reconfiguration. Genuine route/interruption and
                    // media-service notifications still cancel the attempt.
                    if name == .AVAudioEngineConfigurationChange,
                       self.drainUntil != nil, let stoppedAt = self.intentionalPlaybackStopAt,
                       time >= stoppedAt { return }
                    self.cancel(reason: reason)
                    if reason == .audioFailure {
                        self.errorMessage = "Audio configuration or media services changed. Try again."
                    }
                }
            })
        }
        add(AVAudioSession.interruptionNotification, reason: .interrupted)
        add(AVAudioSession.routeChangeNotification, reason: .routeChanged)
        add(.AVAudioEngineConfigurationChange, object: audio.engine, reason: .audioFailure, startupFatal: false)
        add(AVAudioSession.mediaServicesWereLostNotification, reason: .audioFailure)
        add(AVAudioSession.mediaServicesWereResetNotification, reason: .audioFailure)
        add(UIApplication.willResignActiveNotification, reason: .backgrounded)
        add(UIApplication.didEnterBackgroundNotification, reason: .backgrounded)
    }
}
