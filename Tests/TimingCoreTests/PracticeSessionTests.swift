import XCTest
import TimingCore

final class PracticeSessionTests: XCTestCase {
    func testEndObservationCanDrainSeparateInputBatchesWithoutExtendingScoredInterval() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 10) // Count-in 10–14, phrase 14–18.
        for time in [14.0, 15, 16] { session.recordContact(eventTime: time, receivedTime: time) }
        session.advance(to: 18, finalize: false)
        XCTAssertNil(session.result)
        XCTAssertEqual(session.phase, .performing)
        XCTAssertTrue(session.recordContact(eventTime: 17, receivedTime: 18.01))
        session.advance(to: 18.02, finalize: false)
        XCTAssertTrue(session.recordContact(eventTime: 17.999, receivedTime: 18.06))
        XCTAssertFalse(session.recordContact(eventTime: 18, receivedTime: 18.06))
        XCTAssertNil(session.result)
        session.advance(to: 18.1)
        XCTAssertEqual(session.result?.counts.onTime, 4)
        XCTAssertEqual(session.result?.counts.extra, 1)
        XCTAssertEqual(session.result?.score, 80)

        try session.start(at: 20)
        session.advance(to: 28, finalize: false)
        session.cancel(reason: .backgrounded)
        session.advance(to: 28.1)
        XCTAssertNil(session.result)
    }

    func testHalfPointRoundingDoesNotChangeWithDeviceUptime() throws {
        for uptime in [0.0, 100.123, 1000.0, 1000.123, 10000.123, 1_000_000.123] {
            var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
            try session.start(at: uptime)
            // Independently worked example: .75 + .5 + .25 + 0 points = 37.5%.
            for offset in [4.075, 5.1, 6.125, 7.15] {
                session.recordContact(eventTime: uptime + offset, receivedTime: uptime + 8)
            }
            session.advance(to: uptime + 8)
            XCTAssertEqual(session.result?.score, 38, "uptime \(uptime)")
            try session.start(at: uptime)
            for offset in [4.075001, 5.1, 6.125, 7.15] {
                session.recordContact(eventTime: uptime + offset, receivedTime: uptime + 8)
            }
            session.advance(to: uptime + 8)
            XCTAssertEqual(session.result?.score, 37, "A real below-half score must still round down")
        }
    }

    func testPreDownbeatMatchingBoundaryIsInclusiveAndUnmatchedPrestartNeverExtra() throws {
        for (offset, expectedMisses) in [(-0.15, 3), (-0.15000001, 4)] {
            var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
            try session.start(at: 100.123)
            let start = try XCTUnwrap(session.performanceStartTime)
            XCTAssertTrue(session.recordContact(eventTime: start + offset, receivedTime: start))
            session.advance(to: 109)
            let result = try XCTUnwrap(session.result)
            XCTAssertEqual(result.counts.missed, expectedMisses)
            XCTAssertEqual(result.counts.extra, 0)
            XCTAssertEqual(result.score, 0)
            if expectedMisses == 3 {
                XCTAssertEqual(result.targets[0].judgment, .early)
                XCTAssertEqual(result.targets[0].tapID, 0)
                XCTAssertEqual(result.taps[0].targetID, 0)
                XCTAssertEqual(result.taps[0].beat, -0.15, accuracy: 1e-9)
            } else {
                XCTAssertTrue(result.taps.isEmpty)
            }
        }
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 10)
        session.recordContact(eventTime: 13.99, receivedTime: 18)
        session.recordContact(eventTime: 14, receivedTime: 18)
        session.advance(to: 18)
        XCTAssertEqual(session.result?.targets[0].tapID, 1)
        XCTAssertEqual(session.result?.taps.map(\.id), [1])
        XCTAssertEqual(session.result?.counts.extra, 0)
    }

    func testInvalidTempoAndTemporalInputsAreRejectedWithoutDamagingLiveAttempt() throws {
        for bpm in [Int.min, -1, 0, 29, 241, Int.max] {
            XCTAssertThrowsError(try PracticeSession(exercise: Exercise.catalog[0], bpm: bpm))
        }
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        XCTAssertFalse(session.recordContact(eventTime: 10, receivedTime: 10))
        try session.start(at: 10)
        for time in [Double.nan, .infinity, -.infinity, -1, .greatestFiniteMagnitude] {
            XCTAssertThrowsError(try session.start(at: time))
            XCTAssertThrowsError(try session.listen(at: time))
            XCTAssertEqual(session.phase, .countIn)
            XCTAssertEqual(session.performanceStartTime, 14)
        }
        for (event, receipt) in [(Double.nan, 14.0), (14, Double.nan), (.infinity, .infinity),
                                 (14, .infinity), (-1, 14), (9.999, 14), (18, 18), (14, 13.999)] {
            XCTAssertFalse(session.recordContact(eventTime: event, receivedTime: receipt))
        }
        for time in [Double.nan, .infinity, -.infinity, -1] { session.advance(to: time) }
        XCTAssertEqual(session.phase, .countIn)
        let contact = PracticeContact(eventTime: 14, receivedTime: 18.25)
        XCTAssertTrue(session.recordContact(eventTime: contact.eventTime, receivedTime: contact.receivedTime))
        XCTAssertTrue(session.recordContact(eventTime: 17.999, receivedTime: 18.25))
        XCTAssertNil(session.result)
        session.advance(to: 18.25)
        XCTAssertEqual(session.result?.taps.map(\.id), [0, 1])
        XCTAssertEqual(session.result?.counts.onTime, 1)
        XCTAssertEqual(session.result?.counts.extra, 1)
        try session.listen(at: 30)
        XCTAssertNil(session.result)
        XCTAssertNil(session.performanceStartTime)
        session.advance(to: 34)
        XCTAssertEqual(session.phase, .ready)
    }

    func testScoresUseAuthorizedPercentExamplesAndLinearCreditWithoutClockRealignment() throws {
        let eight = [14.0, 14.5, 15, 15.5, 16, 16.5, 17, 17.5]
        for (times, score) in [(eight, 100), (Array(eight.dropLast()), 88), (eight + [17.75], 89), ([], 0)] {
            var session = try PracticeSession(exercise: Exercise.catalog[1], bpm: 60)
            try session.start(at: 10)
            for time in times { session.recordContact(eventTime: time, receivedTime: 18) }
            session.advance(to: 18)
            XCTAssertEqual(session.result?.score, score)
        }
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 0)
        for time in [4.075, 5.1, 6.125, 7.15] {
            session.recordContact(eventTime: time, receivedTime: 8)
        }
        session.advance(to: 8)
        XCTAssertEqual(session.result?.score, 38) // Credits .75 + .5 + .25 + 0 = 1.5 / 4.
        XCTAssertEqual(session.result?.counts.late, 4)
        try session.start(at: 10)
        for time in [14.1, 15.1, 16.1, 17.1] {
            session.recordContact(eventTime: time, receivedTime: 18)
        }
        session.advance(to: 18)
        XCTAssertEqual(session.result?.score, 50) // Consistent lateness is never shifted away.
        XCTAssertEqual(session.result?.counts.late, 4)
    }

    func testMatchingMaximizesCardinalityThenErrorThenChronologicalTargetAndTap() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[1], bpm: 240)
        try session.start(at: 10) // Eighth-note targets at 11, 11.125, 11.25, ...
        for time in [11.0625, 11.125, 11.1875] {
            session.recordContact(eventTime: time, receivedTime: 12)
        }
        session.advance(to: 12)
        // Three matches cost 0.125s; two could cost only 0.0625s. Cardinality wins.
        XCTAssertEqual(session.result?.targets.map(\.tapID), [0, 1, 2, nil, nil, nil, nil, nil])
        XCTAssertEqual(session.result?.counts.missed, 5)
        XCTAssertEqual(session.result?.counts.extra, 0)
        XCTAssertEqual(session.result?.score, 13) // Boundary matches earn zero; exact middle earns one.

        try session.start(at: 10)
        for time in [11.1875, 11.0625] { session.recordContact(eventTime: time, receivedTime: 12) }
        session.advance(to: 12)
        XCTAssertEqual(session.result?.targets.map(\.tapID), [1, 0, nil, nil, nil, nil, nil, nil])

        var quarters = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try quarters.start(at: 10)
        for time in [14.03, 14.01] { quarters.recordContact(eventTime: time, receivedTime: 18) }
        quarters.advance(to: 18)
        // Both earn full credit, but the second input is closer.
        XCTAssertEqual(quarters.result?.targets[0].tapID, 1)
        try quarters.start(at: 10)
        for time in [14.03, 13.97] { quarters.recordContact(eventTime: time, receivedTime: 18) }
        quarters.advance(to: 18)
        XCTAssertEqual(quarters.result?.targets[0].tapID, 1) // Earlier time precedes lower original ID.
        XCTAssertEqual(quarters.result?.taps.map(\.id), [1, 0])
    }

    func testTempoWindowsIncludeExactBoundariesWithoutWideningThresholds() throws {
        let cases: [(Int, Double, Double)] = [(30, 0.05, 0.15), (60, 0.05, 0.15),
                                             (90, 0.05, 0.15), (120, 0.05, 0.125), (240, 0.025, 0.0625)]
        for (bpm, onTime, matching) in cases {
            var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: bpm)
            XCTAssertEqual(session.onTimeWindow, onTime, accuracy: 1e-12)
            XCTAssertEqual(session.matchingWindow, matching, accuracy: 1e-12)
            try session.start(at: 100.123)
            let start = try XCTUnwrap(session.performanceStartTime)
            let interval = 60 / Double(bpm)
            for (beat, offset) in [onTime, -onTime, matching, -matching].enumerated() {
                let time = start + Double(beat) * interval + offset
                session.recordContact(eventTime: time, receivedTime: 200)
            }
            session.advance(to: 200)
            let result = try XCTUnwrap(session.result)
            XCTAssertEqual(result.targets.map(\.judgment), [.onTime, .onTime, .late, .early], "BPM \(bpm)")
            XCTAssertEqual(result.score, 50)
            XCTAssertEqual(result.counts.missed, 0)
            XCTAssertEqual(result.counts.extra, 0)

            try session.start(at: 100.123)
            for (beat, offset) in [onTime + 1e-8, -onTime - 1e-8, matching + 1e-8, -matching - 1e-8].enumerated() {
                session.recordContact(eventTime: start + Double(beat) * interval + offset, receivedTime: 200)
            }
            session.advance(to: 200)
            XCTAssertEqual(session.result?.targets.map(\.judgment), [.late, .early, .missed, .missed])
            XCTAssertEqual(session.result?.counts.extra, 2)
        }
    }

    func testCapacityCancelsOnContact2049IncludingWarmupAndResetClearsStorage() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[1], bpm: 240)
        try session.start(at: 10)
        for _ in 0..<2048 {
            XCTAssertTrue(session.recordContact(eventTime: 10, receivedTime: 10))
        }
        XCTAssertEqual(session.phase, .countIn)
        XCTAssertFalse(session.recordContact(eventTime: 11, receivedTime: 11))
        XCTAssertEqual(session.phase, .cancelled)
        XCTAssertEqual(session.cancellationReason, .capacityReached)
        session.advance(to: 12)
        XCTAssertNil(session.result)
        session.reset()
        try session.start(at: 20)
        for _ in 0..<2048 { session.recordContact(eventTime: 21, receivedTime: 21) }
        session.advance(to: 22)
        XCTAssertEqual(session.result?.counts.onTime, 1)
        XCTAssertEqual(session.result?.counts.extra, 2047)
        XCTAssertEqual(session.result?.targets[0].tapID, 0)
        XCTAssertEqual(session.result?.taps.count, 2048)
    }

    func testCancellationSealsEveryActiveStageAndCompletedReviewSurvivesLateLifecycleEvents() throws {
        for reason in [StopReason.manual, .backgrounded, .interrupted, .routeChanged, .audioFailure] {
            for stage in 0..<4 {
                var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
                if stage == 1 { try session.listen(at: 10) }
                if stage >= 2 { try session.start(at: 10) }
                if stage == 3 { session.advance(to: 14) }
                session.cancel(reason: reason)
                session.cancel(reason: .capacityReached)
                session.advance(to: 100)
                XCTAssertEqual(session.phase, .cancelled)
                XCTAssertEqual(session.cancellationReason, reason)
                XCTAssertNil(session.audioPlan)
                XCTAssertNil(session.result)
                XCTAssertFalse(session.recordContact(eventTime: 14, receivedTime: 14))
                session.reset()
                XCTAssertEqual(session.phase, .ready)
                XCTAssertNil(session.performanceStartTime)
                XCTAssertNil(session.cancellationReason)
            }
        }
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 10)
        session.advance(to: 18)
        XCTAssertEqual(session.result?.score, 0)
        XCTAssertEqual(session.result?.counts.missed, 4)
        XCTAssertEqual(session.result?.taps.count, 0)
        session.cancel(reason: .backgrounded)
        session.advance(to: 100)
        XCTAssertFalse(session.recordContact(eventTime: 14, receivedTime: 100))
        XCTAssertEqual(session.phase, .review)
        XCTAssertEqual(session.result?.counts.missed, 4)
        XCTAssertNil(session.cancellationReason)
        try session.start(at: 30)
        XCTAssertNil(session.result)
        XCTAssertEqual(session.performanceStartTime, 34)
        session.cancel(reason: .manual)
        try session.listen(at: 40)
        XCTAssertNil(session.cancellationReason)
        XCTAssertEqual(session.phase, .listening)
    }

    func testFirstNoteGraceChoosesClosestContactAndDiscardsUnmatchedWarmup() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 10)
        for time in [10.0, 13.84, 13.86, 13.98, 14.1, 15, 16, 17] {
            session.recordContact(eventTime: time, receivedTime: 18.1)
        }
        session.advance(to: 18)
        let result = try XCTUnwrap(session.result)
        XCTAssertEqual(result.targets[0].tapID, 3)
        XCTAssertEqual(result.taps.map(\.id), [3, 4, 5, 6, 7])
        XCTAssertEqual(result.taps[0].beat, -0.02, accuracy: 1e-9)
        XCTAssertEqual(result.counts.onTime, 4)
        XCTAssertEqual(result.counts.extra, 1)
        XCTAssertEqual(result.score, 80)

        var rest = try PracticeSession(exercise: Exercise.catalog[2], bpm: 60)
        try rest.start(at: 10)
        for time in [13.98, 14, 15, 17, 18, 20] {
            rest.recordContact(eventTime: time, receivedTime: 22)
        }
        rest.advance(to: 21.999)
        XCTAssertNil(rest.result)
        rest.advance(to: 22)
        let restResult = try XCTUnwrap(rest.result)
        XCTAssertEqual(restResult.taps.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(restResult.taps[0].judgment, .extra)
        XCTAssertEqual(restResult.counts.extra, 1)
        XCTAssertEqual(restResult.score, 80)
    }

    func testWholePhraseMatchingKeepsOriginalIDsAndDoesNotCascadeMissesOrExtras() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[0], bpm: 60)
        try session.start(at: 10) // Targets 14, 15, 16, 17.
        for time in [17.0, 14, 15.5, 16, 16] {
            XCTAssertTrue(session.recordContact(eventTime: time, receivedTime: 19))
        }
        XCTAssertNil(session.result) // Late delivery must not finalize a partial batch.
        session.advance(to: 19)
        XCTAssertEqual(session.phase, .review)
        let result = try XCTUnwrap(session.result)
        XCTAssertEqual(result.score, 50) // Three points / (four targets + two extras).
        XCTAssertEqual(result.counts.onTime, 3)
        XCTAssertEqual(result.counts.early, 0)
        XCTAssertEqual(result.counts.late, 0)
        XCTAssertEqual(result.counts.missed, 1)
        XCTAssertEqual(result.counts.extra, 2)
        XCTAssertEqual(result.targets.map(\.tapID), [1, nil, 3, 0])
        XCTAssertEqual(result.targets.map(\.judgment), [.onTime, .missed, .onTime, .onTime])
        XCTAssertEqual(result.taps.map(\.id), [1, 2, 3, 4, 0])
        XCTAssertEqual(result.taps.map(\.targetID), [0, nil, 2, nil, 3])
        XCTAssertEqual(result.taps.map(\.beat), [0, 1.5, 2, 2, 3])
        XCTAssertEqual(result.performanceStartTime, 14)
        XCTAssertEqual(result.beatInterval, 1)
        XCTAssertEqual(result.barCount, 1)
    }

    func testStartReplacesListenWithFreshCountInAndObservationOnlyChangesPhase() throws {
        var session = try PracticeSession(exercise: Exercise.catalog[2], bpm: 120)
        try session.listen(at: 10)
        XCTAssertFalse(session.recordContact(eventTime: 11, receivedTime: 11))
        session.advance(to: 14)
        XCTAssertEqual(session.phase, .ready)
        try session.listen(at: 20)
        try session.start(at: 21)
        XCTAssertEqual(session.phase, .countIn)
        XCTAssertEqual(session.performanceStartTime, 23)
        XCTAssertEqual(session.audioPlan?.metronome.startTime, 21)
        XCTAssertEqual(session.audioPlan?.metronome.endTime, 27)
        XCTAssertEqual(session.audioPlan?.metronome.beats.count, 12)
        XCTAssertEqual(session.audioPlan?.demonstrationOnsets, [])
        XCTAssertTrue(session.recordContact(eventTime: 21, receivedTime: 21))
        session.advance(to: 22.999)
        XCTAssertEqual(session.phase, .countIn)
        session.advance(to: 26.75)
        XCTAssertEqual(session.phase, .performing) // Includes the trailing rest.
        session.advance(to: 22)
        XCTAssertEqual(session.phase, .performing)
        XCTAssertEqual(session.audioPlan?.metronome.endTime, 27)
    }

    func testCatalogNotationAndListenTimelineCoverCompleteBars() throws {
        let onsets: [[Double]] = [[0, 1, 2, 3], [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5],
                                 [1, 3, 4, 6], [0, 1.5, 2, 3.5, 4.5, 5, 6.5, 7]]
        XCTAssertEqual(Exercise.catalog.count, 4)
        XCTAssertEqual(Set(Exercise.catalog.map(\.id)).count, 4)
        for (index, exercise) in Exercise.catalog.enumerated() {
            var session = try PracticeSession(exercise: exercise, bpm: 60)
            XCTAssertEqual(session.phase, .ready)
            XCTAssertEqual(session.exercise.onsetBeats, onsets[index])
            XCTAssertEqual(session.exercise.barCount, index < 2 ? 1 : 2)
            XCTAssertEqual(exercise.symbols.filter { !$0.isRest }.map(\.onset), onsets[index])
            var cursor = 0.0
            for symbol in exercise.symbols {
                XCTAssertEqual(symbol.onset, cursor)
                XCTAssertTrue([0.5, 1].contains(symbol.duration))
                XCTAssertLessThanOrEqual(symbol.onset.truncatingRemainder(dividingBy: 4) + symbol.duration, 4)
                cursor += symbol.duration
            }
            XCTAssertEqual(cursor, index < 2 ? 4 : 8)
            try session.listen(at: 10)
            XCTAssertEqual(session.phase, .listening)
            let plan = try XCTUnwrap(session.audioPlan)
            XCTAssertEqual(plan.demonstrationOnsets, onsets[index].map { 10 + $0 })
            XCTAssertEqual(plan.metronome.endTime, index < 2 ? 14 : 18)
            XCTAssertEqual(plan.metronome.beats.filter(\.isAccent).map(\.scheduledTime), index < 2 ? [10] : [10, 14])
        }
    }
}
