import SwiftUI
import TimingCore

/// Small vector engraver for the approved quarter/eighth percussion vocabulary.
/// No font-dependent musical Unicode fallbacks. Spacing follows note value and
/// glyph clearance, not the proportional time axis used by review.
struct RhythmNotationView: View {
    let exercise: Exercise
    var rowHeight: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<exercise.barCount, id: \.self) { bar in
                let symbols = exercise.symbols.filter { Int($0.onset / 4) == bar }
                Canvas { context, size in
                    drawBar(symbols: symbols, bar: bar, in: &context, size: size)
                }
                .frame(height: rowHeight)
                .accessibilityLabel("Bar \(bar + 1), four four. " + symbols.map { symbol in
                    let value = symbol.duration == 1 ? "quarter" : "eighth"
                    let beat = symbol.onset - Double(bar * 4) + 1
                    return "\(value) \(symbol.isRest ? "rest" : "note") at beat \(beat)"
                }.joined(separator: ", "))
            }
        }
    }

    private func drawBar(symbols: [RhythmSymbol], bar: Int, in context: inout GraphicsContext, size: CGSize) {
        let top: CGFloat = 29
        let gap: CGFloat = 8
        let middle = top + 2 * gap
        let end = size.width - 8
        var staff = Path()
        for line in 0..<5 {
            let y = top + CGFloat(line) * gap
            staff.move(to: CGPoint(x: 8, y: y)); staff.addLine(to: CGPoint(x: end, y: y))
        }
        for x in [CGFloat(8), end] {
            staff.move(to: CGPoint(x: x, y: top)); staff.addLine(to: CGPoint(x: x, y: top + 4 * gap))
        }
        context.stroke(staff, with: .foreground, lineWidth: 0.7)
        // Neutral percussion clef: two vertical bars across the middle staff spaces.
        for x in [CGFloat(19), 26] {
            context.fill(Path(CGRect(x: x, y: top + gap, width: 3.5, height: 2 * gap)), with: .foreground)
        }
        context.draw(Text("4").font(.system(size: 18, weight: .bold, design: .serif)),
                     at: CGPoint(x: 44, y: top + gap))
        context.draw(Text("4").font(.system(size: 18, weight: .bold, design: .serif)),
                     at: CGPoint(x: 44, y: top + 3 * gap))
        context.draw(Text("Bar \(bar + 1)").font(.caption2).foregroundColor(.secondary),
                     at: CGPoint(x: 8, y: 10), anchor: .leading)
        let left: CGFloat = 62
        let available = max(1, end - left - 13)
        let weights = symbols.map { $0.duration == 1 ? 1.6 : 1.0 }
        let total = weights.reduce(0, +)
        var cumulative = 0.0
        let positions: [CGFloat] = weights.map { weight in
            defer { cumulative += weight }
            return left + available * CGFloat((cumulative + 0.3) / total)
        }
        for index in symbols.indices {
            let symbol = symbols[index]
            let x = positions[index]
            if symbol.isRest {
                drawRest(eighth: symbol.duration == 0.5, at: CGPoint(x: x, y: middle), in: &context)
                continue
            }
            // A filled oval on the same staff position for every unpitched hit.
            let oval = Path(ellipseIn: CGRect(x: -5.5, y: -3.6, width: 11, height: 7.2))
            let transform = CGAffineTransform(rotationAngle: -.pi / 8).concatenating(
                CGAffineTransform(translationX: x, y: middle))
            context.fill(oval.applying(transform), with: .foreground)
            var stem = Path()
            stem.move(to: CGPoint(x: x + 5, y: middle))
            stem.addLine(to: CGPoint(x: x + 5, y: middle - 29))
            context.stroke(stem, with: .foreground, lineWidth: 1.3)
            guard symbol.duration == 0.5 else { continue }
            let isSecond = index > 0 && canBeam(symbols[index - 1], symbol)
            let isFirst = index + 1 < symbols.count && canBeam(symbol, symbols[index + 1])
            if isFirst {
                var beam = Path()
                beam.move(to: CGPoint(x: x + 5, y: middle - 29))
                beam.addLine(to: CGPoint(x: positions[index + 1] + 5, y: middle - 29))
                context.stroke(beam, with: .foreground, lineWidth: 3.5)
            } else if !isSecond {
                var flag = Path()
                flag.move(to: CGPoint(x: x + 5, y: middle - 29))
                flag.addCurve(to: CGPoint(x: x + 9, y: middle - 10),
                              control1: CGPoint(x: x + 6, y: middle - 19),
                              control2: CGPoint(x: x + 20, y: middle - 22))
                context.stroke(flag, with: .foreground, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
    }

    private func canBeam(_ left: RhythmSymbol, _ right: RhythmSymbol) -> Bool {
        !left.isRest && !right.isRest && left.duration == 0.5 && right.duration == 0.5
            && Int(left.onset) == Int(right.onset) && right.onset - left.onset == 0.5
    }

    private func drawRest(eighth: Bool, at point: CGPoint, in context: inout GraphicsContext) {
        var path = Path()
        let x = point.x, y = point.y
        if eighth {
            context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 6, width: 6, height: 6)), with: .foreground)
            path.move(to: CGPoint(x: x - 2, y: y - 2))
            path.addQuadCurve(to: CGPoint(x: x + 6, y: y - 7), control: CGPoint(x: x + 4, y: y + 1))
            path.addLine(to: CGPoint(x: x + 1, y: y + 13))
        } else {
            path.move(to: CGPoint(x: x - 3, y: y - 14))
            path.addLine(to: CGPoint(x: x + 4, y: y - 6))
            path.addLine(to: CGPoint(x: x - 3, y: y + 1))
            path.addLine(to: CGPoint(x: x + 4, y: y + 8))
            path.addCurve(to: CGPoint(x: x + 2, y: y + 16),
                          control1: CGPoint(x: x - 8, y: y + 3),
                          control2: CGPoint(x: x - 6, y: y + 13))
        }
        context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
    }
}
