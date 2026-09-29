import SwiftUI
import TimingCore

private enum ReviewSelection: Hashable, Identifiable {
    case target(Int), tap(Int)
    var id: Self { self }
}

extension Judgment {
    var label: String {
        switch self {
        case .onTime: return "On time"
        case .early: return "Early"
        case .late: return "Late"
        case .missed: return "Missed"
        case .extra: return "Extra"
        }
    }
}

struct PracticeReviewView: View {
    let exercise: Exercise
    let bpm: Int
    let result: PracticeResult
    @State private var selection: ReviewSelection?
    @State private var nearby: [ReviewSelection] = []
    @State private var selectedBar: Int?
    @State private var showsScoring = false
    @ScaledMetric(relativeTo: .caption) private var countWidth: CGFloat = 72

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(exercise.title).font(.headline)
                Text("\(bpm) BPM").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("\(result.score) / 100").font(.largeTitle.bold().monospacedDigit()).accessibilityLabel("Accuracy \(result.score) out of 100")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: countWidth))], spacing: 8) {
                count("On time", result.counts.onTime)
                count("Early", result.counts.early)
                count("Late", result.counts.late)
                count("Missed", result.counts.missed)
                count("Extra", result.counts.extra)
            }
            Button("How scoring works") { showsScoring = true }
                .font(.caption)
                .frame(minHeight: 44)
                .tint(AppTheme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your timing").font(.headline)
                Text("○ Target   ● Your tap").font(.callout)
                Text("Tap a marker to inspect it. The timeline uses true time spacing, independently of the notation.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(0..<result.barCount, id: \.self) { bar in
                    timeline(bar: bar)
                }
            }
            RhythmNotationView(exercise: exercise)
        }
        .sheet(isPresented: $showsScoring) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Each target is worth an equal share of 100 points.")
                        Text("On time earns full credit. Early or late earns half credit. Missed earns no credit. Each extra tap subtracts one full target’s value.")
                        Text("Score = 100 × (on time + 0.5 × (early + late) − extras) ÷ targets")
                            .font(.callout.monospaced())
                        Text("The score cannot fall below 0 and is rounded to the nearest whole number. Only all on-time targets with no extras earn 100; other results are capped at 99.")
                    }
                    .padding()
                }
                .background(AppTheme.background)
                .navigationTitle("How scoring works")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsScoring = false }
                    }
                }
            }
            .tint(AppTheme.accent)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func count(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.monospacedDigit())
            Text(label).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func timeline(bar: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bar \(bar + 1)").font(.caption.bold())
            GeometryReader { geometry in
                Canvas { context, size in
                    for subdivision in 0...8 {
                        let beat = Double(subdivision) / 2
                        let x = position(beat, width: size.width)
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: 23)); line.addLine(to: CGPoint(x: x, y: 75))
                        context.stroke(line, with: .color(.secondary.opacity(subdivision % 2 == 0 ? 0.5 : 0.2)),
                                       style: StrokeStyle(lineWidth: 1, dash: subdivision % 2 == 0 ? [] : [2, 3]))
                        if subdivision < 8 {
                            context.draw(Text(subdivision % 2 == 0 ? "\(subdivision / 2 + 1)" : "&").font(.caption2),
                                         at: CGPoint(x: x, y: 12))
                        }
                    }
                    // Draw targets first, actual contacts second, on the same lane.
                    for target in result.targets where row(for: target.beat) == bar {
                        let x = position(target.beat - Double(bar * 4), width: size.width)
                        let selected = targetSelected(target)
                        context.stroke(Path(ellipseIn: CGRect(x: x - 7, y: 44, width: 14, height: 14)),
                                        with: .color(selected ? AppTheme.selection : .primary), lineWidth: selected ? 3 : 1.5)
                    }
                    for tap in result.taps where row(for: tap.beat) == bar {
                        let x = position(tap.beat - Double(bar * 4), width: size.width)
                        let selected = tapSelected(tap)
                        context.fill(Path(ellipseIn: CGRect(x: x - 4, y: 47, width: 8, height: 8)),
                                      with: .color(selected ? AppTheme.selection : AppTheme.accent))
                        if selected {
                            context.stroke(Path(ellipseIn: CGRect(x: x - 9, y: 42, width: 18, height: 18)),
                                            with: .color(AppTheme.selection), lineWidth: 1)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { value in
                    let candidates = markers(bar: bar).filter {
                        abs(position(localBeat($0, bar: bar), width: geometry.size.width) - value.location.x) <= 22
                            && abs(value.location.y - 51) <= 25
                    }.sorted {
                        abs(position(localBeat($0, bar: bar), width: geometry.size.width) - value.location.x)
                            < abs(position(localBeat($1, bar: bar), width: geometry.size.width) - value.location.x)
                    }
                    nearby = candidates.count > 1 ? candidates : []
                    selection = candidates.first
                    selectedBar = candidates.isEmpty ? nil : bar
                })
                .accessibilityRepresentation {
                    VStack {
                        ForEach(markers(bar: bar)) { item in
                            Button("Bar \(bar + 1), \(description(item))") {
                                selection = item
                                selectedBar = bar
                                nearby = []
                            }
                            .accessibilityHint("Selects this marker and highlights its matched partner, if any.")
                            .accessibilityAddTraits(isHighlighted(item) ? [.isSelected] : [])
                        }
                    }
                }
            }
            .frame(height: 82)
            if selectedBar == bar, let selection {
                Text(description(selection))
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if nearby.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose a nearby marker").font(.caption).foregroundStyle(.secondary)
                        ForEach(nearby) { item in
                            Button(description(item)) { self.selection = item }
                                .font(.callout)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(isHighlighted(item) ? [.isSelected] : [])
                        }
                    }
                    .tint(AppTheme.accent)
                }
            }
        }
        .padding(8)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    // Equal-sized margins make negative first-note offsets visible without
    // clamping or exaggerating them. Every bar keeps the same beat scale.
    private func position(_ beat: Double, width: CGFloat) -> CGFloat {
        8 + CGFloat((beat + 0.25) / 4.5) * max(1, width - 16)
    }

    private func row(for beat: Double) -> Int { min(result.barCount - 1, max(0, Int(floor(beat / 4)))) }

    private func markers(bar: Int) -> [ReviewSelection] {
        result.targets.filter { row(for: $0.beat) == bar }.map { .target($0.id) }
            + result.taps.filter { row(for: $0.beat) == bar }.map { .tap($0.id) }
    }

    private func localBeat(_ item: ReviewSelection, bar: Int) -> Double {
        switch item {
        case .target(let id): return (result.targets.first { $0.id == id }?.beat ?? 0) - Double(bar * 4)
        case .tap(let id): return (result.taps.first { $0.id == id }?.beat ?? 0) - Double(bar * 4)
        }
    }

    private func targetSelected(_ target: ReviewTarget) -> Bool {
        selection == .target(target.id) || target.tapID.map { selection == .tap($0) } == true
    }

    private func tapSelected(_ tap: ReviewTap) -> Bool {
        selection == .tap(tap.id) || tap.targetID.map { selection == .target($0) } == true
    }

    private func description(_ item: ReviewSelection) -> String {
        switch item {
        case .target(let id):
            guard let target = result.targets.first(where: { $0.id == id }) else { return "Target" }
            let partner = target.tapID.flatMap { tapID in result.taps.firstIndex { $0.id == tapID } }
            return "Target \(id + 1), \(musicalPosition(target.beat)): \(target.judgment.label)"
                + (partner.map { " — matched to tap \($0 + 1), \(musicalPosition(result.taps[$0].beat))" } ?? " — no matched tap")
        case .tap(let id):
            guard let index = result.taps.firstIndex(where: { $0.id == id }) else { return "Tap" }
            let tap = result.taps[index]
            let partner = tap.targetID.flatMap { targetID in result.targets.first { $0.id == targetID } }
            return "Tap \(index + 1), \(musicalPosition(tap.beat)): \(tap.judgment.label)"
                + (partner.map { " — matched to target \($0.id + 1), \(musicalPosition($0.beat))" } ?? " — no matched target")
        }
    }

    private func musicalPosition(_ beat: Double) -> String {
        if beat < 0 { return "before bar 1" }
        let bar = row(for: beat)
        let beatNumber = min(4, Int(beat - Double(bar * 4)) + 1)
        return "bar \(bar + 1), beat \(beatNumber)"
    }

    private func isHighlighted(_ item: ReviewSelection) -> Bool {
        switch item {
        case .target(let id): return result.targets.first { $0.id == id }.map(targetSelected) ?? false
        case .tap(let id): return result.taps.first { $0.id == id }.map(tapSelected) ?? false
        }
    }
}
