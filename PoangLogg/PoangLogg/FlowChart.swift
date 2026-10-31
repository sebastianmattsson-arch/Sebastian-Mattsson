import SwiftUI

struct FlowSelection: Equatable {
    let game: Int
    let index: Int
}

/// Ledning poäng för poäng i ett set, med en remsa för förlorade poäng under.
struct FlowChart: View {
    @Environment(Store.self) private var store
    let match: Match
    let game: Int
    @Binding var selected: FlowSelection?

    private let height: CGFloat = 150
    private let pl: CGFloat = 26, pr: CGFloat = 10, pt: CGFloat = 12, pb: CGFloat = 40

    var body: some View {
        let ev = match.events(inGame: game)
        let last = ev.last.map { GameScore(me: $0.me, opp: $0.opp) } ?? GameScore()

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Set \(game)").fontWeight(.semibold)
                Spacer()
                Text("\(last.me)–\(last.opp)").monospacedDigit().foregroundStyle(Theme.muted)
            }
            .font(.system(size: 15))
            .padding(.horizontal, 4)

            GeometryReader { geo in
                let g = Geometry(width: geo.size.width, height: height, count: ev.count,
                                 maxAbs: max(3, ev.map { abs($0.me - $0.opp) }.max() ?? 0),
                                 pl: pl, pr: pr, pt: pt, pb: pb)
                let colors = ev.map { store.color(for: $0.reason) }
                let sel = selected?.game == game ? selected?.index : nil

                Canvas { ctx, _ in
                    draw(in: &ctx, g: g, ev: ev, colors: colors, selected: sel)
                }
                .contentShape(Rectangle())
                .onTapGesture { loc in
                    guard !ev.isEmpty else { return }
                    let i = Int(((loc.x - g.pl) / g.step).rounded()) - 1
                    selected = FlowSelection(game: game, index: min(max(i, 0), ev.count - 1))
                }
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Ledning poäng för poäng i set \(game), \(last.me)–\(last.opp)")
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.rule, lineWidth: 1.5))
    }

    struct Geometry {
        let width: CGFloat, height: CGFloat, count: Int, maxAbs: Int
        let pl: CGFloat, pr: CGFloat, pt: CGFloat, pb: CGFloat

        var n: CGFloat { CGFloat(max(10, count)) }
        var plotH: CGFloat { height - pt - pb }
        var step: CGFloat { (width - pl - pr) / n }
        func x(_ i: Int) -> CGFloat { pl + step * CGFloat(i) }
        func y(_ d: Int) -> CGFloat { pt + plotH / 2 - CGFloat(d) / CGFloat(maxAbs) * plotH / 2 }
    }

    private func draw(in ctx: inout GraphicsContext, g: Geometry, ev: [PointEvent], colors: [Color], selected: Int?) {
        // Övre halvan: spelaren leder.
        ctx.fill(Path(CGRect(x: g.pl, y: g.pt, width: g.width - g.pl - g.pr, height: g.plotH / 2)),
                 with: .color(Theme.winSoft.opacity(0.6)))

        let ax = Font.system(size: 10)
        func label(_ s: String, _ p: CGPoint, _ anchor: UnitPoint) {
            ctx.draw(Text(s).font(ax).foregroundStyle(Theme.muted), at: p, anchor: anchor)
        }
        label("\(store.state.player) leder", CGPoint(x: g.pl + 4, y: g.pt + 2), .topLeading)
        label("\(match.opponent) leder", CGPoint(x: g.pl + 4, y: g.pt + g.plotH - 2), .bottomLeading)
        label("+\(g.maxAbs)", CGPoint(x: g.pl - 6, y: g.y(g.maxAbs)), .trailing)
        label("0", CGPoint(x: g.pl - 6, y: g.y(0)), .trailing)
        label("−\(g.maxAbs)", CGPoint(x: g.pl - 6, y: g.y(-g.maxAbs)), .trailing)

        var zero = Path()
        zero.move(to: CGPoint(x: g.pl, y: g.y(0)))
        zero.addLine(to: CGPoint(x: g.width - g.pr, y: g.y(0)))
        ctx.stroke(zero, with: .color(Theme.muted), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        var line = Path()
        line.move(to: CGPoint(x: g.x(0), y: g.y(0)))
        for (i, e) in ev.enumerated() { line.addLine(to: CGPoint(x: g.x(i + 1), y: g.y(e.me - e.opp))) }
        ctx.stroke(line, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        label("Förlorade poäng", CGPoint(x: g.pl, y: g.height - g.pb + 10), .bottomLeading)

        for (i, e) in ev.enumerated() {
            let c = CGPoint(x: g.x(i + 1), y: g.y(e.me - e.opp))
            let r: CGFloat = e.kind == .won ? 4 : 5
            let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(colors[i]))
            ctx.stroke(dot, with: .color(i == selected ? Theme.ink : Theme.surface), lineWidth: i == selected ? 2.5 : 1.5)

            if e.kind == .lost {
                let w = max(2, g.step - 1)
                let rect = CGRect(x: c.x - g.step / 2 + 0.5, y: g.height - g.pb + 14, width: w, height: 14)
                let p = Path(roundedRect: rect, cornerRadius: 2)
                ctx.fill(p, with: .color(colors[i]))
                if i == selected { ctx.stroke(p, with: .color(Theme.ink), lineWidth: 2.5) }
            }
        }
    }
}
