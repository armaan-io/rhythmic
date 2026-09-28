import XCTest
import TimingCore

final class TimingSessionTests: XCTestCase {
    func testExportPreservesScheduledTimesRawContactsAndCancellationReason() throws {
        var session = try TimingSession(bpm: 120, startTime: 100, barCount: 1)
        session.recordTap(eventTime: 100.02, receivedTime: 100.04)
        session.stop(at: 101, reason: .routeChanged)
        let data = try JSONEncoder().encode(session)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["bpm"] as? Int, 120)
        XCTAssertEqual(json["startTime"] as? Double, 100)
        XCTAssertEqual(json["endTime"] as? Double, 102)
        XCTAssertEqual(json["beatInterval"] as? Double, 0.5)
        let beats = try XCTUnwrap(json["beats"] as? [[String: Any]])
        XCTAssertEqual(beats.count, 4)
        XCTAssertEqual(beats[3]["scheduledTime"] as? Double, 101.5)
        let taps = try XCTUnwrap(json["taps"] as? [[String: Any]])
        XCTAssertEqual(taps.count, 1)
        XCTAssertEqual(taps[0]["eventTime"] as? Double, 100.02)
        XCTAssertEqual(taps[0]["receivedTime"] as? Double, 100.04)
        let stop = try XCTUnwrap(json["stopEvent"] as? [String: Any])
        XCTAssertEqual(stop["reason"] as? String, "routeChanged")
        XCTAssertEqual(stop["time"] as? Double, 101)
    }

    func testDiagnosticCapacityStopsInsteadOfGrowingMemoryWithoutBound() throws {
        var session = try TimingSession(bpm: 120, startTime: 100)
        for _ in 0..<10_000 {
            XCTAssertTrue(session.recordTap(eventTime: 101, receivedTime: 101.01))
        }
        XCTAssertFalse(session.recordTap(eventTime: 102, receivedTime: 102.01))
        XCTAssertEqual(session.taps.count, 10_000)
        XCTAssertEqual(session.stopEvent?.reason, .capacityReached)
        XCTAssertEqual(session.stopEvent?.time, 102.01)
    }

    func testStopAndInterruptionReasonsSealTheRunWithoutOverwritingEarlierEvents() throws {
        for reason in [StopReason.manual, .backgrounded, .interrupted,
                       .routeChanged, .audioFailure] {
            var session = try TimingSession(bpm: 120, startTime: 100)
            XCTAssertTrue(session.recordTap(eventTime: 100.5, receivedTime: 100.51))
            session.stop(at: 101, reason: reason)
            session.stop(at: 102, reason: .manual)
            XCTAssertFalse(session.recordTap(eventTime: 100.9, receivedTime: 101.1))
            XCTAssertEqual(session.stopEvent?.time, 101)
            XCTAssertEqual(session.stopEvent?.reason, reason)
            XCTAssertEqual(session.taps.count, 1)
        }
    }

    func testCompletionRequiresPhraseEndAndCancellationCanPrecedeScheduledStart() throws {
        var session = try TimingSession(bpm: 120, startTime: 100, barCount: 1)
        session.stop(at: .nan, reason: .manual)
        session.stop(at: -1, reason: .manual)
        session.stop(at: 101.9, reason: .completed)
        XCTAssertNil(session.stopEvent)
        session.stop(at: 102.03, reason: .completed)
        XCTAssertEqual(session.stopEvent?.time, 102)
        XCTAssertEqual(session.stopEvent?.reason, .completed)

        var cancelled = try TimingSession(bpm: 120, startTime: 100)
        cancelled.stop(at: 99.9, reason: .backgrounded)
        XCTAssertEqual(cancelled.stopEvent?.time, 99.9)
        XCTAssertTrue(cancelled.taps.isEmpty)
    }

    func testRejectsOutOfRunAndInvalidTimestampEventsWithoutChangingRecordedData() throws {
        var session = try TimingSession(bpm: 120, startTime: 100, barCount: 1)
        for (event, receipt) in [(99.999, 100.0), (102, 102), (101, 100),
                                 (Double.nan, 101), (101, Double.infinity),
                                 (Double.infinity, Double.infinity), (101, Double.nan)] {
            XCTAssertFalse(session.recordTap(eventTime: event, receivedTime: receipt))
        }
        XCTAssertTrue(session.taps.isEmpty)
    }

    func testRecordsIndependentContactsAndRetainsEventAndReceiptTimes() throws {
        var session = try TimingSession(bpm: 120, startTime: 100, barCount: 1)
        XCTAssertTrue(session.recordTap(eventTime: 100, receivedTime: 100.01))
        XCTAssertTrue(session.recordTap(eventTime: 100, receivedTime: 100.01))
        XCTAssertTrue(session.recordTap(eventTime: 101.999, receivedTime: 102.01))
        // Delivery can be delayed or out of event-time order: retain raw facts.
        XCTAssertTrue(session.recordTap(eventTime: 101, receivedTime: 102.02))
        XCTAssertEqual(session.taps.map(\.eventTime), [100, 100, 101.999, 101])
        XCTAssertEqual(session.taps.map(\.receivedTime), [100.01, 100.01, 102.01, 102.02])
    }

    func testRejectsUnsupportedConfiguration() {
        for bpm in [0, 29, 241] {
            XCTAssertThrowsError(try TimingSession(bpm: bpm, startTime: 100))
        }
        for time in [-1.0, .infinity, .nan, Double.greatestFiniteMagnitude] {
            XCTAssertThrowsError(try TimingSession(bpm: 120, startTime: time))
        }
        for bars in [Int.min, -1, 0, 17, Int.max] {
            XCTAssertThrowsError(try TimingSession(bpm: 120, startTime: 100, barCount: bars))
        }
    }

    func testTempoExtremesBoundTheRunWithoutAccumulatingBeatDrift() throws {
        let slow = try TimingSession(bpm: 30, startTime: 0)
        XCTAssertEqual(slow.beats.count, 64)
        XCTAssertEqual(slow.beats.last?.scheduledTime, 126)
        XCTAssertEqual(slow.endTime, 128)
        let fast = try TimingSession(bpm: 240, startTime: 10)
        XCTAssertEqual(fast.beats.last?.scheduledTime, 25.75)
        XCTAssertEqual(fast.endTime, 26)
    }

    func testBeatScheduleUsesAbsoluteTimesAndAccentsEveryFourthBeat() throws {
        let session = try TimingSession(bpm: 120, startTime: 100, barCount: 2)

        XCTAssertEqual(session.beats.map(\.scheduledTime), [100, 100.5, 101, 101.5, 102, 102.5, 103, 103.5])
        XCTAssertEqual(session.beats.map(\.isAccent), [true, false, false, false, true, false, false, false])
        XCTAssertEqual(session.endTime, 104)
    }
}
