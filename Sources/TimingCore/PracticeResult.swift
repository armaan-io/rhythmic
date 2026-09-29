public enum Judgment: String, CaseIterable, Sendable {
    case onTime, early, late, missed, extra
}

public struct ResultCounts: Sendable {
    public let onTime: Int
    public let early: Int
    public let late: Int
    public let missed: Int
    public let extra: Int
}

public struct ReviewTarget: Identifiable, Sendable {
    public let id: Int
    public let beat: Double
    public let time: Double
    public let judgment: Judgment
    public let tapID: Int?
}

public struct ReviewTap: Identifiable, Sendable {
    public let id: Int
    public let beat: Double
    public let time: Double
    public let judgment: Judgment
    public let targetID: Int?
}

public struct PracticeResult: Sendable {
    public let score: Int
    public let counts: ResultCounts
    public let targets: [ReviewTarget]
    public let taps: [ReviewTap]
    public let performanceStartTime: Double
    public let beatInterval: Double
    public let barCount: Int
}

extension PracticeResult {
    // Suffix DP stores only the objective and first pair, never a copied match path.
    // Identical first pairs share the same canonical optimal suffix. Comparing the
    // first pair therefore also resolves lexicographic ties in constant time.
    private struct Match {
        var count = 0
        var error = 0.0
        var target = Int.max
        var tap = Int.max

        func precedes(_ other: Match) -> Bool {
            if count != other.count { return count > other.count }
            if abs(error - other.error) > 1e-9 { return error < other.error }
            if target != other.target { return target < other.target }
            return tap < other.tap
        }
    }

    init(exercise: Exercise, start: Double, interval: Double, contacts: [PracticeContact],
         onTime: Double, window: Double) {
        let beats = exercise.onsetBeats
        let times = beats.map { start + $0 * interval }
        let ordered = contacts.enumerated().filter {
            $0.element.eventTime >= start || (beats.first == 0 && start - $0.element.eventTime <= window + 1e-9)
        }.sorted {
            if $0.element.eventTime != $1.element.eventTime { return $0.element.eventTime < $1.element.eventTime }
            return $0.offset < $1.offset
        }
        let width = ordered.count + 1
        var table = Array(repeating: Match(), count: (times.count + 1) * width)
        for i in times.indices.reversed() {
            for j in ordered.indices.reversed() {
                var best = table[(i + 1) * width + j]
                let skipTap = table[i * width + j + 1]
                if skipTap.precedes(best) { best = skipTap }
                let error = abs(ordered[j].element.eventTime - times[i])
                let eligible = ordered[j].element.eventTime >= start || (i == 0 && beats[i] == 0)
                if eligible && error <= window + 1e-9 {
                    let suffix = table[(i + 1) * width + j + 1]
                    let match = Match(count: suffix.count + 1, error: suffix.error + error, target: i, tap: j)
                    if match.precedes(best) { best = match }
                }
                table[i * width + j] = best
            }
        }
        var targetTaps: [Int: Int] = [:]
        var tapTargets: [Int: Int] = [:]
        var cell = table[0]
        while cell.count > 0 {
            targetTaps[cell.target] = cell.tap
            tapTargets[cell.tap] = cell.target
            cell = table[(cell.target + 1) * width + cell.tap + 1]
        }
        func judgment(_ offset: Double) -> Judgment {
            abs(offset) <= onTime + 1e-9 ? .onTime : (offset < 0 ? .early : .late)
        }
        targets = times.indices.map { i in
            let j = targetTaps[i]
            return ReviewTarget(id: i, beat: beats[i], time: times[i],
                                judgment: j.map { judgment(ordered[$0].element.eventTime - times[i]) } ?? .missed,
                                tapID: j.map { ordered[$0].offset })
        }
        taps = ordered.indices.compactMap { j in
            let time = ordered[j].element.eventTime
            let i = tapTargets[j]
            guard time >= start || i != nil else { return nil }
            return ReviewTap(id: ordered[j].offset, beat: (time - start) / interval, time: time,
                             judgment: i.map { judgment(time - times[$0]) } ?? .extra, targetID: i)
        }
        counts = ResultCounts(onTime: targets.filter { $0.judgment == .onTime }.count,
                              early: targets.filter { $0.judgment == .early }.count,
                              late: targets.filter { $0.judgment == .late }.count,
                              missed: targets.filter { $0.judgment == .missed }.count,
                              extra: taps.filter { $0.judgment == .extra }.count)
        let points = Double(counts.onTime) + 0.5 * Double(counts.early + counts.late)
        let roundedScore = Int(max(0, 100 * (points - Double(counts.extra)) / Double(times.count)).rounded())
        // Rounding must never turn an imperfect attempt into a perfect score.
        let isPerfect = counts.onTime == times.count && counts.extra == 0
        score = isPerfect ? 100 : min(99, roundedScore)
        performanceStartTime = start
        beatInterval = interval
        barCount = exercise.barCount
    }
}
