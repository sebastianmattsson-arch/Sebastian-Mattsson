import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class Store {
    var state: AppState {
        didSet {
            persist()
            if state.liveEnabled { scheduleLivePublish() }
        }
    }

    /// Senaste status för livescoren, visas i livescore-vyn.
    var liveStatus: String?
    private var liveTask: Task<Void, Never>?

    struct Toast: Equatable {
        let id = UUID()
        let text: String
    }

    var toast: Toast?

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("poanglogg.json")
    }

    init() {
        if let data = try? Data(contentsOf: Store.fileURL),
           var saved = try? JSONDecoder().decode(AppState.self, from: data) {
            saved.migrate()
            state = saved
        } else {
            state = AppState()
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: Store.fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            show("Kunde inte spara: \(error.localizedDescription)")
        }
    }

    func show(_ text: String) {
        withAnimation { toast = Toast(text: text) }
    }

    // MARK: - Matcher

    var current: Match? { state.matches.first { $0.id == state.currentId } }
    var currentIndex: Int? { state.matches.firstIndex { $0.id == state.currentId } }

    var matchLabel: String {
        guard let m = current, let i = currentIndex else { return "Starta en match" }
        var s = "Match \(i + 1) av \(state.matches.count)"
        if !m.round.isEmpty { s += " · \(m.round)" }
        return s + " · set \(m.games.count)"
    }

    func newMatch(opponent: String, round: String, to: Int) {
        state.lastTo = to
        let m = Match(
            id: UUID().uuidString,
            opponent: opponent.isEmpty ? "Motståndare" : opponent,
            round: round, to: to, created: .now,
            games: [GameScore()], events: [], firstServer: nil)
        state.matches.append(m)
        state.currentId = m.id
    }

    private func ensureMatch() -> Int {
        if let i = currentIndex { return i }
        newMatch(opponent: "", round: "", to: state.lastTo)
        return state.matches.count - 1
    }

    func addPoint(_ kind: PointKind, reason: String?) {
        let i = ensureMatch()
        var m = state.matches[i]
        var g = m.game
        if kind == .won { g.me += 1 } else { g.opp += 1 }
        m.games[m.games.count - 1] = g
        m.events.append(PointEvent(kind: kind, reason: reason, game: m.games.count,
                                   time: .now, me: g.me, opp: g.opp))
        state.matches[i] = m
        if g.isDone(to: m.to) {
            let winner = g.me > g.opp ? state.player : m.opponent
            show("\(winner) vann setet \(g.me)–\(g.opp). Tryck Nästa set.")
        }
    }

    func undo() {
        guard let i = currentIndex else { return }
        var m = state.matches[i]
        guard let ev = m.events.popLast() else {
            if m.games.count > 1 && m.game.isEmpty {
                m.games.removeLast()
                state.matches[i] = m
                show("Setet borttaget")
            }
            return
        }
        while m.games.count > ev.game { m.games.removeLast() }
        if ev.kind == .won { m.games[ev.game - 1].me -= 1 } else { m.games[ev.game - 1].opp -= 1 }
        state.matches[i] = m
        show("Ångrade")
    }

    func nextGame() {
        let i = ensureMatch()
        var m = state.matches[i]
        if m.game.isEmpty { show("Setet har inga poäng än"); return }
        if m.games.count >= 3 { show("Max tre set"); return }
        m.games.append(GameScore())
        state.matches[i] = m
        show("Set \(m.games.count) startat")
    }

    func canStep(_ delta: Int) -> Bool {
        guard let i = currentIndex else { return false }
        return state.matches.indices.contains(i + delta)
    }

    func step(_ delta: Int) {
        guard let i = currentIndex, state.matches.indices.contains(i + delta) else { return }
        select(state.matches[i + delta].id)
    }

    func select(_ id: String) {
        guard let i = state.matches.firstIndex(where: { $0.id == id }) else { return }
        state.currentId = id
        show("Match \(i + 1): mot \(state.matches[i].opponent)")
    }

    func deleteMatch(_ id: String) {
        state.matches.removeAll { $0.id == id }
        if state.currentId == id { state.currentId = state.matches.last?.id }
        show("Matchen raderad")
    }

    func setFirstServer(_ side: Side) {
        guard let i = currentIndex else { return }
        state.matches[i].firstServer = side
        let who = side == .me ? state.player : state.matches[i].opponent
        show("\(who) servar först")
    }

    // MARK: - Inställningar

    func addReason(label: String, type: ReasonType) {
        state.reasons.append(Reason(id: "c" + UUID().uuidString.prefix(8).lowercased(), label: label, type: type))
    }

    func deleteReason(_ id: String) {
        state.reasons.removeAll { $0.id == id && $0.isCustom }
    }

    func resetAll() {
        let live = (state.liveEnabled, state.liveCode, state.followCode)
        var fresh = AppState(player: state.player)
        (fresh.liveEnabled, fresh.liveCode, fresh.followCode) = live
        state = fresh
        show("Allt raderat")
    }

    // MARK: - Livescore

    func setLiveEnabled(_ on: Bool) {
        if on && state.liveCode == nil { state.liveCode = LiveService.makeCode() }
        state.liveEnabled = on
        liveStatus = on ? "Ansluter …" : nil
        if !on { liveTask?.cancel() }
    }

    func newLiveCode() {
        state.liveCode = LiveService.makeCode()
        show("Ny kod: \(state.liveCode ?? "")")
    }

    var liveInvite: String {
        "Följ \(state.player)s badmintonmatcher live i appen Poänglogg. Tryck på sändningsikonen överst och skriv in koden: \(state.liveCode ?? "")"
    }

    private func scheduleLivePublish() {
        guard let code = state.liveCode else { return }
        liveTask?.cancel()
        liveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }
            let doc = self.state.liveDoc()
            do {
                try await LiveService.publish(doc, code: code)
                guard !Task.isCancelled else { return }
                self.liveStatus = "Uppdaterad " + Date.now.formatted(date: .omitted, time: .shortened)
            } catch {
                guard !Task.isCancelled else { return }
                self.liveStatus = LiveService.describe(error)
            }
        }
    }

    // MARK: - Hjälpare

    func reason(_ id: String?) -> Reason {
        guard let id else { return Reason(id: "", label: "Vann – ingen orsak", type: .unspec) }
        return state.reasons.first { $0.id == id } ?? Reason(id: id, label: id, type: .own)
    }

    func color(for id: String?) -> Color {
        let r = reason(id)
        if r.type == .unspec { return Theme.win }
        let list = state.reasons.filter { $0.type == r.type }
        let idx = list.firstIndex { $0.id == id } ?? 0
        let pal = Theme.palette(r.type)
        return pal[idx % pal.count]
    }

    func summary() -> String {
        var lines = ["\(state.player) – poänglogg", ""]
        for (i, m) in state.matches.enumerated() where !m.events.isEmpty {
            lines.append("Match \(i + 1): mot \(m.opponent)\(m.round.isEmpty ? "" : " (\(m.round))")")
            lines.append("Set: " + m.games.map { "\($0.me)–\($0.opp)" }.joined(separator: ", "))
            let lost = m.events.filter { $0.kind == .lost }
            let own = lost.filter { reason($0.reason).type == .own }.count
            lines.append("Förlorade poäng: \(lost.count) (eget fel \(own), motståndaren \(lost.count - own))")
            for row in counted(lost) {
                lines.append("  \(reason(row.reason).label): \(row.count)")
            }
            let won = m.events.filter { $0.kind == .won }
            let oe = won.filter { reason($0.reason).type == .opperr }.count
            let wi = won.filter { reason($0.reason).type == .winner }.count
            let un = won.count - oe - wi
            lines.append("Vunna poäng: \(won.count) (motståndarens fel \(oe), egna vinnare \(wi)\(un > 0 ? ", utan orsak \(un)" : ""))")
            for row in counted(won.filter { $0.reason != nil }) {
                let r = reason(row.reason)
                lines.append("  \(r.label) (\(r.type.text)): \(row.count)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    struct ReasonCount: Identifiable {
        let reason: String?
        let count: Int
        var id: String { reason ?? "" }
    }

    /// Antal poäng per orsak, flest först (vid lika antal i den ordning de först hände).
    func counted(_ events: [PointEvent]) -> [ReasonCount] {
        var c: [String: Int] = [:]
        var order: [String?] = []
        for e in events {
            let key = e.reason ?? ""
            if c[key] == nil { order.append(e.reason) }
            c[key, default: 0] += 1
        }
        return order.enumerated()
            .map { (i: $0.offset, row: ReasonCount(reason: $0.element, count: c[$0.element ?? ""] ?? 0)) }
            .sorted { $0.row.count != $1.row.count ? $0.row.count > $1.row.count : $0.i < $1.i }
            .map(\.row)
    }
}
