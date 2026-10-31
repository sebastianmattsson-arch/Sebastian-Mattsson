import SwiftUI

struct LogView: View {
    @Environment(Store.self) private var store
    @State private var mode: PointKind = .lost
    @State private var taps = 0

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        let player = store.state.player
        let m = store.current

        VStack(alignment: .leading, spacing: 0) {
            if let m, m.firstServer == nil {
                serveAsk(m)
            }

            HStack(spacing: 8) {
                modeButton(.lost, title: "\(player) tappade")
                modeButton(.won, title: "\(player) vann")
            }
            .padding(.top, 10)

            if mode == .lost {
                SectionTitle(title: "Eget fel", subtitle: "missade själv")
                grid(.own)
                SectionTitle(title: "Motståndaren vann den", subtitle: "tvingad förlust")
                grid(.forced)
            } else {
                SectionTitle(title: "Motståndarens fel", subtitle: "gav bort poängen")
                grid(.opperr)
                SectionTitle(title: "\(player)s vinnare", subtitle: "vann den själv")
                grid(.winner)
                Button("Vann – hoppa över orsak") { point(.won, nil) }
                    .buttonStyle(PlainBoxStyle())
                    .padding(.top, 8)
            }

            HStack(spacing: 8) {
                Button("Ångra senaste") { store.undo() }.buttonStyle(PlainBoxStyle())
                Button("Nästa set") { store.nextGame() }.buttonStyle(PlainBoxStyle())
            }
            .padding(.top, 14)

            SectionTitle(title: "Senaste poängen")
            recentLog(m)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    private func point(_ kind: PointKind, _ reason: String?) {
        store.addPoint(kind, reason: reason)
        taps += 1
    }

    // MARK: - Delar

    private func serveAsk(_ m: Match) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(m.events.isEmpty
                 ? "Vem servar först? (lottningen)"
                 : "Vem servade först i set 1? Då räknas serven ut för alla poäng.")
                .fontWeight(.semibold)
            HStack(spacing: 8) {
                Button(store.state.player) { store.setFirstServer(.me) }
                Button(m.opponent) { store.setFirstServer(.opp) }
            }
            .buttonStyle(PlainBoxStyle())
            .lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.red, lineWidth: 1.5))
        .padding(.top, 10)
    }

    private func modeButton(_ kind: PointKind, title: String) -> some View {
        let on = mode == kind
        let fill: Color = kind == .lost ? Theme.own : Theme.win
        let text: Color = kind == .lost ? .white : Theme.onWin
        return Button { mode = kind } label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13).padding(.horizontal, 8)
                .foregroundStyle(on ? text : Theme.muted)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? fill : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? fill : Theme.rule, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func grid(_ type: ReasonType) -> some View {
        let counts = Dictionary(grouping: store.current?.events ?? [], by: { $0.reason ?? "" })
            .mapValues(\.count)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(store.state.reasons.filter { $0.type == type }) { r in
                ReasonButton(reason: r, count: counts[r.id] ?? 0) {
                    point(type.pointKind, r.id)
                }
            }
        }
    }

    @ViewBuilder
    private func recentLog(_ m: Match?) -> some View {
        let evs = Array((m?.events ?? []).suffix(8).reversed())
        VStack(spacing: 0) {
            Divider().overlay(Theme.rule)
            if evs.isEmpty {
                Text("Tryck på en orsak när \(store.state.player) tappar en poäng.")
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            ForEach(evs) { e in
                let r = store.reason(e.reason)
                let text = e.kind == .won
                    ? (e.reason != nil ? "Vann: \(r.label) (\(r.type.text))" : "\(store.state.player) vann")
                    : r.label
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(store.color(for: e.reason)).frame(width: 9, height: 9)
                    Text(text)
                    Spacer(minLength: 8)
                    Text("Set \(e.game) · \(e.me)–\(e.opp)")
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .fixedSize()
                }
                .font(.system(size: 15))
                .padding(.vertical, 8).padding(.horizontal, 2)
                Divider().overlay(Theme.rule)
            }
        }
    }
}

struct ReasonButton: View {
    let reason: Reason
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(reason.label)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .padding(.leading, 16).padding(.trailing, 28).padding(.vertical, 14)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 18, weight: .bold).width(.condensed))
                        .monospacedDigit()
                        .opacity(0.55)
                        .padding(.trailing, 10).padding(.top, 8)
                }
            }
            .frame(minHeight: 62)
            .foregroundStyle(Theme.ink)
            .background(Theme.soft(reason.type))
            .overlay(alignment: .leading) { Theme.accent(reason.type).frame(width: 6) }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(count > 0 ? "\(reason.label), \(count) gånger" : reason.label)
    }
}
