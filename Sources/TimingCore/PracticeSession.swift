public enum PracticePhase: String, Sendable {
    case ready, listening, countIn, performing, review, cancelled
}

public struct PracticeAudioPlan: Sendable {
    public let metronome: TimingSession
    public let demonstrationOnsets: [Double]
}

public struct PracticeContact: Sendable {
    public let eventTime: Double
    public let receivedTime: Double

    public init(eventTime: Double, receivedTime: Double) {
        self.eventTime = eventTime
        self.receivedTime = receivedTime
    }
}

/// Deterministic uptime-clock state; the caller renders and schedules the audio plan.
public struct PracticeSession: Sendable {
    public let exercise: Exercise
    public let bpm: Int
    public private(set) var phase: PracticePhase = .ready
    public private(set) var audioPlan: PracticeAudioPlan?
    public private(set) var performanceStartTime: Double?
    public private(set) var result: PracticeResult?
    public private(set) var cancellationReason: StopReason?
    public var onTimeWindow: Double { min(0.05, max(0.025, 0.1 * 60 / Double(bpm))) }
    public var matchingWindow: Double { min(0.15, 0.25 * 60 / Double(bpm)) }
    private var contacts: [PracticeContact] = []

    public init(exercise: Exercise, bpm: Int) throws {
        guard (30...240).contains(bpm) else { throw TimingSession.ConfigurationError.invalidTempo }
        self.exercise = exercise
        self.bpm = bpm
    }

    public mutating func listen(at time: Double) throws {
        let metronome = try TimingSession(bpm: bpm, startTime: time, barCount: exercise.barCount)
        audioPlan = PracticeAudioPlan(metronome: metronome,
                                     demonstrationOnsets: exercise.onsetBeats.map { time + $0 * metronome.beatInterval })
        phase = .listening
        cancellationReason = nil
        result = nil
        performanceStartTime = nil
        contacts.removeAll(keepingCapacity: true)
    }

    public mutating func start(at time: Double) throws {
        let metronome = try TimingSession(bpm: bpm, startTime: time, barCount: exercise.barCount + 1)
        audioPlan = PracticeAudioPlan(metronome: metronome, demonstrationOnsets: [])
        performanceStartTime = time + 4 * metronome.beatInterval
        contacts.removeAll(keepingCapacity: true)
        phase = .countIn
        cancellationReason = nil
        result = nil
    }

    /// Observe progress; never schedules audio. A native adapter may defer final
    /// review while draining already-occurred input. Event eligibility still ends
    /// at the written phrase boundary, regardless of when review is finalized.
    public mutating func advance(to time: Double, finalize: Bool = true) {
        guard time.isFinite, let plan = audioPlan else { return }
        if phase == .listening, time >= plan.metronome.endTime {
            phase = .ready
            audioPlan = nil
        } else if phase == .countIn || phase == .performing, let start = performanceStartTime {
            if time >= plan.metronome.endTime && finalize {
                result = PracticeResult(exercise: exercise, start: start, interval: plan.metronome.beatInterval,
                                        contacts: contacts, onTime: onTimeWindow, window: matchingWindow)
                phase = .review
            } else if time >= start {
                phase = .performing
            }
        }
    }

    /// Acceptance permits tap audio. Judgments are deferred until advance reaches the end.
    @discardableResult
    public mutating func recordContact(eventTime: Double, receivedTime: Double) -> Bool {
        guard phase == .countIn || phase == .performing,
              let plan = audioPlan, eventTime.isFinite, receivedTime.isFinite,
              eventTime >= plan.metronome.startTime, eventTime < plan.metronome.endTime,
              receivedTime >= eventTime else { return false }
        guard contacts.count < 2048 else {
            cancel(reason: .capacityReached)
            return false
        }
        contacts.append(PracticeContact(eventTime: eventTime, receivedTime: receivedTime))
        return true
    }

    public mutating func cancel(reason: StopReason) {
        guard phase != .review, phase != .cancelled else { return }
        phase = .cancelled
        cancellationReason = reason
        audioPlan = nil
        contacts.removeAll(keepingCapacity: true)
    }

    public mutating func reset() {
        phase = .ready
        audioPlan = nil
        performanceStartTime = nil
        result = nil
        cancellationReason = nil
        contacts.removeAll(keepingCapacity: true)
    }
}
