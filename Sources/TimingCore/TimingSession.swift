import Foundation

public enum StopReason: String, Codable, Sendable {
    case manual, completed, backgrounded, interrupted, routeChanged, audioFailure, capacityReached
}

/// Pure timing data. Times are absolute seconds on the system-uptime clock,
/// not wall-clock dates or measurements of when sound physically reaches ears.
public struct TimingSession: Encodable, Sendable {
    public enum ConfigurationError: Error { case invalidTempo, invalidStartTime, invalidBarCount }
    public struct BeatEvent: Encodable, Sendable {
        public let index: Int
        public let scheduledTime: Double
        public let isAccent: Bool
    }

    public struct TapEvent: Encodable, Sendable {
        public let eventTime: Double
        public let receivedTime: Double
    }

    public struct StopEvent: Encodable, Sendable {
        public let time: Double
        public let reason: StopReason
    }

    public let bpm: Int
    public let startTime: Double
    public let barCount: Int
    public let beats: [BeatEvent]
    public private(set) var taps: [TapEvent] = []
    public private(set) var stopEvent: StopEvent?
    public var beatInterval: Double { 60 / Double(bpm) }
    public var endTime: Double { startTime + Double(barCount * 4) * beatInterval }

    public init(bpm: Int, startTime: Double, barCount: Int = 16) throws {
        guard (30...240).contains(bpm) else { throw ConfigurationError.invalidTempo }
        guard startTime.isFinite, startTime >= 0,
              startTime + 60 / Double(bpm) > startTime else {
            throw ConfigurationError.invalidStartTime
        }
        guard (1...16).contains(barCount) else { throw ConfigurationError.invalidBarCount }
        self.bpm = bpm
        self.startTime = startTime
        self.barCount = barCount
        self.beats = (0..<(barCount * 4)).map { index in
            BeatEvent(index: index, scheduledTime: startTime + Double(index) * 60 / Double(bpm),
                      isAccent: index.isMultiple(of: 4))
        }
    }

    @discardableResult
    public mutating func recordTap(eventTime: Double, receivedTime: Double) -> Bool {
        guard stopEvent == nil, eventTime.isFinite, receivedTime.isFinite,
              eventTime >= startTime, eventTime < endTime, receivedTime >= eventTime else {
            return false
        }
        guard taps.count < 10_000 else {
            stop(at: receivedTime, reason: .capacityReached)
            return false
        }
        taps.append(TapEvent(eventTime: eventTime, receivedTime: receivedTime))
        return true
    }

    /// First stop wins. An interrupted pre-roll may stop before scheduled start.
    /// Completion uses the scheduled end even when the UI observes it later.
    public mutating func stop(at time: Double, reason: StopReason) {
        guard stopEvent == nil, time.isFinite, time >= 0 else { return }
        guard reason != .completed || time >= endTime else { return }
        stopEvent = StopEvent(time: reason == .completed ? endTime : time, reason: reason)
    }

    private enum CodingKeys: String, CodingKey {
        case bpm, startTime, barCount, beats, taps, stopEvent, beatInterval, endTime
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bpm, forKey: .bpm)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(barCount, forKey: .barCount)
        try container.encode(beats, forKey: .beats)
        try container.encode(taps, forKey: .taps)
        try container.encodeIfPresent(stopEvent, forKey: .stopEvent)
        try container.encode(beatInterval, forKey: .beatInterval)
        try container.encode(endTime, forKey: .endTime)
    }
}
