import SwiftUI
import UIKit

struct StatsView: View {
    @Environment(Store.self) private var store
    let onSettings: () -> Void

    /// "match", "game1"…"game3" eller "all".
    @State private var scope = "match"
    @State private var selected: FlowSelection?

    var body: some View {
        let m = store.current
        let ev = scopedEvents(m)

        VStack(alignment: .leading, spacing: 0) {
            playerCard.padding(.top, 10)
            scopeChips(m)

            SectionTitle(title: "Matchförlopp", subtitle: "ledning poäng för poäng")
            flow(m)

            lostSection(ev)
            wonSection(ev)

            SectionTitle(title: "Serve och mottagning")
            serveSection(ev)

            HStack(spacing: 8) {
                ShareLink(item: store.summary()) {
                    Text("Dela sammanfattning")
                }
                .buttonStyle(PlainBoxStyle())
                Button("Kopiera") {
                    UIPasteboard.general.string = store.summary()
                    store.show("Kopierat")
                }
                .buttonStyle(PlainBoxStyle())
            }
            .padding(.top, 14)
            Button("Inställningar", action: onSettings)
                .buttonStyle(PlainBoxStyle())
                .padding(.top, 8)
        }
        .onChange(of: store.state.currentId) { selected = nil }
    }

    // MARK: - Urval

    struct ScopeOption: Identifiable {
        let id: String
        let label: String
    }

    private func scopeOptions(_ m: Match?) -> [ScopeOption] {
        var opts = [ScopeOption(id: "match", label: "Denna match")]
        if let m {
            for i in m.games.indices { opts.append(ScopeOption(id: "game\(i + 1)", label: "Set \(i + 1)")) }
        }
        opts.append(ScopeOption(id: "all", label: "Hela turneringen"))
        return opts
    }

    private func effectiveScope(_ m: Match?) -> String {
        scopeOptions(m).contains { $0.id == scope } ? scope : "match"
    }

    private func scopedEvents(_ m: Match?) -> [PointEvent] {
        let s = effectiveScope(m)
        if s == "all" { return store.state.matches.flatMap(\.events) }
        guard let m else { return [] }
        if s == "match" { return m.events }
        let n = Int(s.dropFirst(4)) ?? 1
        return m.events(inGame: n)
    }

    private func scopeChips(_ m: Match?) -> some View {
        let current = effectiveScope(m)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(scopeOptions(m)) { opt in
                    let on = opt.id == current
                    Button(opt.label) { scope = opt.id; selected = nil }
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(on ? Theme.bg : Theme.ink)
                        .background(Capsule().fill(on ? Theme.ink : Theme.surface))
                        .overlay(Capsule().stroke(on ? Theme.ink : Theme.rule, lineWidth: 1.5))
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Spelarkort

    private var playerCard: some View {
        let all = store.state.matches.flatMap(\.events)
        let nm = store.state.matches.filter { !$0.events.isEmpty }.count
        let won = all.filter { $0.kind == .won }.count
        let sub = nm > 0
            ? "\(nm) \(nm == 1 ? "match" : "matcher") · \(won) vunna, \(all.count - won) förlorade poäng"
            : "Inga matcher loggade än"
        return HStack(spacing: 14) {
            PlayerAvatar(name: store.state.player, size: 72, ring: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.state.player).font(.system(size: 28, weight: .bold).width(.condensed))
                Text(sub).font(.system(size: 15)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.rule, lineWidth: 1.5))
    }

    // MARK: - Förlopp

    @ViewBuilder
    private func flow(_ m: Match?) -> some View {
        let s = effectiveScope(m)
        if s == "all" || m == nil {
            EmptyNote("Välj en match eller ett set för att se förloppet.")
        } else if let m {
            let sets = s.hasPrefix("game") ? [Int(s.dropFirst(4)) ?? 1] : Array(1...m.games.count)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(sets, id: \.self) { n in
                    FlowChart(match: m, game: n, selected: $selected)
                }
                legend(m, sets: sets, kind: .won, title: "Vann:")
                legend(m, sets: sets, kind: .lost, title: "Tappade:")
                Text(flowInfo(m))
                    .font(.system(size: 15))
                    .frame(minHeight: 20, alignment: .leading)
            }
        }
    }

    private func flowInfo(_ m: Match) -> String {
        guard let sel = selected else {
            return m.events.isEmpty ? "" : "Tryck på en punkt eller ruta för att se vad som hände."
        }
        let evs = m.events(inGame: sel.game)
        guard evs.indices.contains(sel.index) else { return "" }
        let e = evs[sel.index]
        let r = store.reason(e.reason)
        let txt = (e.kind == .won ? "\(store.state.player) vann – " : "")
            + (e.reason != nil ? "\(r.label) (\(r.type.text))" : "ingen orsak angiven")
        return "Set \(sel.game), poäng \(sel.index + 1) – ställning \(e.me)–\(e.opp): \(txt)"
    }

    @ViewBuilder
    private func legend(_ m: Match, sets: [Int], kind: PointKind, title: String) -> some View {
        let ids = uniqueReasons(m.events.filter { sets.contains($0.game) && $0.kind == kind })
        if !ids.isEmpty {
            FlowLayout(spacing: 12, lineSpacing: 6) {
                Text(title).fontWeight(.semibold)
                ForEach(ids, id: \.self) { id in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: kind == .won ? 5 : 2)
                            .fill(store.color(for: id.isEmpty ? nil : id))
                            .frame(width: 10, height: 10)
                        Text(id.isEmpty ? "Ingen orsak" : store.reason(id).label)
                    }
                }
            }
            .font(.system(size: 14))
        }
    }

    private func uniqueReasons(_ evs: [PointEvent]) -> [String] {
        var seen: [String] = []
        for e in evs {
            let id = e.reason ?? ""
            if !seen.contains(id) { seen.append(id) }
        }
        return seen
    }

    // MARK: - Förlorade / vunna

    @ViewBuilder
    private func lostSection(_ ev: [PointEvent]) -> some View {
        let lost = ev.filter { $0.kind == .lost }
        let won = ev.count - lost.count
        let own = lost.filter { store.reason($0.reason).type == .own }.count
        let forced = lost.count - own
        let pOwn = lost.isEmpty ? 0 : Int((Double(own) / Double(lost.count) * 100).rounded())

        SectionTitle(title: "Förlorade poäng", subtitle: "\(lost.count) förlorade, \(won) vunna")
        SplitBar(left: Double(own), right: Double(forced), leftColor: Theme.own, rightColor: Theme.forced)
        HStack {
            Text("Eget fel: \(own)" + (lost.isEmpty ? "" : " (\(pOwn) %)"))
            Spacer()
            Text("Motståndaren: \(forced)" + (lost.isEmpty ? "" : " (\(100 - pOwn) %)"))
        }
        .font(.system(size: 14)).foregroundStyle(Theme.muted)

        SectionTitle(title: "Varför")
        let rows = store.counted(lost)
        if rows.isEmpty {
            EmptyNote("Inga förlorade poäng loggade här än.")
        } else {
            let mx = Double(rows[0].count)
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    let r = store.reason(row.reason)
                    BarRow(label: r.label,
                           value: "\(row.count) · \(pct(row.count, lost.count)) %",
                           fraction: Double(row.count) / mx,
                           color: r.type == .own ? Theme.own : Theme.forced)
                }
            }
        }
    }

    @ViewBuilder
    private func wonSection(_ ev: [PointEvent]) -> some View {
        let wonEv = ev.filter { $0.kind == .won }
        let oe = wonEv.filter { store.reason($0.reason).type == .opperr }.count
        let wi = wonEv.filter { store.reason($0.reason).type == .winner }.count
        let un = wonEv.count - oe - wi
        let known = oe + wi
        let pOe = known == 0 ? 0 : pct(oe, known)

        SectionTitle(title: "Vunna poäng", subtitle: "\(wonEv.count) vunna" + (un > 0 ? ", \(un) utan orsak" : ""))
        SplitBar(left: Double(oe), right: Double(wi), leftColor: Theme.oe[0], rightColor: Theme.win)
        HStack {
            Text("Motståndarens fel: \(oe)" + (known > 0 ? " (\(pOe) %)" : ""))
            Spacer()
            Text("Egna vinnare: \(wi)" + (known > 0 ? " (\(100 - pOe) %)" : ""))
        }
        .font(.system(size: 14)).foregroundStyle(Theme.muted)

        SectionTitle(title: "Hur")
        let rows = store.counted(wonEv.filter { $0.reason != nil })
        if rows.isEmpty {
            EmptyNote("Inga vunna poäng med orsak loggade här än.")
        } else {
            let mx = Double(rows[0].count)
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    let r = store.reason(row.reason)
                    BarRow(label: r.label,
                           detail: r.type.text,
                           value: "\(row.count) · \(pct(row.count, known)) %",
                           fraction: Double(row.count) / mx,
                           color: r.type == .opperr ? Theme.oe[0] : Theme.win)
                }
            }
        }
    }

    @ViewBuilder
    private func serveSection(_ ev: [PointEvent]) -> some View {
        let srvMap = serverMap()
        let sOwn = ev.filter { srvMap[$0.id] == .me }
        let sRec = ev.filter { srvMap[$0.id] == .opp }
        let unknown = ev.count - sOwn.count - sRec.count

        if sOwn.isEmpty && sRec.isEmpty {
            EmptyNote("Välj vem som servar först på Logga-fliken, så räknas serven ut automatiskt.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                serveRow("När \(store.state.player) servar", sOwn)
                serveRow("När motståndaren servar", sRec)
                if unknown > 0 {
                    EmptyNote("\(unknown) poäng i första setet saknar serveinfo. Välj vem som servade först på Logga-fliken.")
                }
            }
        }
    }

    private func serveRow(_ label: String, _ arr: [PointEvent]) -> some View {
        let w = arr.filter { $0.kind == .won }.count
        let pc = arr.isEmpty ? 0 : pct(w, arr.count)
        return BarRow(label: label,
                      value: "vann \(w) av \(arr.count)" + (arr.isEmpty ? "" : " · \(pc) %"),
                      fraction: Double(pc) / 100,
                      color: Theme.win)
    }

    private func serverMap() -> [UUID: Side] {
        var map: [UUID: Side] = [:]
        for m in store.state.matches {
            for (e, s) in zip(m.events, m.servers()) {
                if let s { map[e.id] = s }
            }
        }
        return map
    }

    private func pct(_ n: Int, _ total: Int) -> Int {
        total == 0 ? 0 : Int((Double(n) / Double(total) * 100).rounded())
    }
}

// MARK: - Små komponenter

struct EmptyNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10).padding(.horizontal, 2)
    }
}

struct SplitBar: View {
    let left: Double
    let right: Double
    let leftColor: Color
    let rightColor: Color

    var body: some View {
        GeometryReader { geo in
            let total = left + right
            HStack(spacing: 0) {
                if total > 0 {
                    leftColor.frame(width: geo.size.width * left / total)
                    rightColor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.rule)
            .clipShape(Capsule())
        }
        .frame(height: 14)
        .padding(.top, 6).padding(.bottom, 4)
    }
}

struct BarRow: View {
    let label: String
    var detail: String? = nil
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label) + Text(detail.map { " · \($0)" } ?? "").foregroundStyle(Theme.muted)
                Spacer(minLength: 10)
                Text(value).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .font(.system(size: 15))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, fraction)))
                }
            }
            .frame(height: 10)
        }
    }
}

/// Enkel radbrytande layout för förklaringar.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += lineH + lineSpacing; x = 0; lineH = 0 }
            x += s.width + spacing
            lineH = max(lineH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { y += lineH + lineSpacing; x = bounds.minX; lineH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}
