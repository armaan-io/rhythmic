public struct RhythmSymbol: Identifiable, Equatable, Sendable {
    public let id: Int
    public let onset: Double
    public let duration: Double
    public let isRest: Bool
}

public struct Exercise: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let skill: String
    public let barCount: Int
    public let symbols: [RhythmSymbol]
    public var onsetBeats: [Double] { symbols.filter { !$0.isRest }.map(\.onset) }

    private init(id: String, title: String, skill: String, bars: Int,
                 values: [(Double, Bool)]) {
        self.id = id
        self.title = title
        self.skill = skill
        barCount = bars
        var onset = 0.0
        symbols = values.enumerated().map { index, value in
            defer { onset += value.0 }
            return RhythmSymbol(id: index, onset: onset, duration: value.0, isRest: value.1)
        }
    }

    public static let catalog: [Exercise] = [
        Exercise(id: "steady-quarters", title: "Steady quarters", skill: "Quarter-note timing", bars: 1,
                 values: Array(repeating: (1, false), count: 4)),
        Exercise(id: "eighth-note-pulse", title: "Eighth-note pulse", skill: "Eighth-note subdivisions", bars: 1,
                 values: Array(repeating: (0.5, false), count: 8)),
        Exercise(id: "space-between-notes", title: "Space between notes", skill: "Rests", bars: 2,
                 values: [(1, true), (1, false), (1, true), (1, false),
                          (1, false), (1, true), (1, false), (1, true)]),
        Exercise(id: "offbeat-entrances", title: "Offbeat entrances", skill: "Simple syncopation", bars: 2,
                 values: [(1, false), (0.5, true), (0.5, false), (1, false), (0.5, true), (0.5, false),
                          (0.5, true), (0.5, false), (1, false), (0.5, true), (0.5, false), (1, false)])
    ]
}
