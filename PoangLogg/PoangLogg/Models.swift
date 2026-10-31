import Foundation

enum ReasonType: String, Codable, CaseIterable, Identifiable {
    case own, forced, opperr, winner, unspec

    var id: String { rawValue }

    /// Typer som går att välja för en egen orsak.
    static let selectable: [ReasonType] = [.own, .forced, .opperr, .winner]

    /// Beskrivning som används i loggen och statistiken.
    var text: String {
        switch self {
        case .own: return "eget fel"
        case .forced: return "motståndaren vann den"
        case .opperr: return "motståndarens fel"
        case .winner: return "egen vinnare"
        case .unspec: return "ingen orsak angiven"
        }
    }

    /// Namn i inställningarna.
    var pickerLabel: String {
        switch self {
        case .own: return "Eget fel"
        case .forced: return "Motståndaren vann den"
        case .opperr: return "Vann – motståndarens fel"
        case .winner: return "Vann – egen vinnare"
        case .unspec: return "Ingen orsak"
        }
    }

    var pointKind: PointKind {
        switch self {
        case .own, .forced: return .lost
        case .opperr, .winner, .unspec: return .won
        }
    }
}

struct Reason: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var type: ReasonType

    var isCustom: Bool { !Reason.defaults.contains { $0.id == id } }

    static let defaults: [Reason] = [
        Reason(id: "net", label: "I nätet", type: .own),
        Reason(id: "long", label: "Ut bakåt", type: .own),
        Reason(id: "wide", label: "Ut på sidan", type: .own),
        Reason(id: "serve", label: "Servefel", type: .own),
        Reason(id: "miss", label: "Bom / felträff", type: .own),
        Reason(id: "short", label: "För kort – gav upp smash", type: .own),
        Reason(id: "smash", label: "Smash / vinnare", type: .forced),
        Reason(id: "drop", label: "Dropp / fint", type: .forced),
        Reason(id: "late", label: "Hann inte fram", type: .forced),
        Reason(id: "place", label: "Placering bakom", type: .forced),
        Reason(id: "o_net", label: "I nätet", type: .opperr),
        Reason(id: "o_out", label: "Slog ut", type: .opperr),
        Reason(id: "o_serve", label: "Servefel", type: .opperr),
        Reason(id: "o_miss", label: "Bom / felträff", type: .opperr),
        Reason(id: "w_smash", label: "Smash", type: .winner),
        Reason(id: "w_drop", label: "Dropp / nätspel", type: .winner),
        Reason(id: "w_place", label: "Placering / passering", type: .winner),
        Reason(id: "w_drive", label: "Drive / snabb retur", type: .winner),
    ]
}

enum PointKind: String, Codable { case won, lost }
enum Side: String, Codable { case me, opp }

struct GameScore: Codable, Hashable {
    var me = 0
    var opp = 0

    var isEmpty: Bool { me == 0 && opp == 0 }

    /// Setet är slut vid `to` poäng med två poängs marginal, eller vid taket (21 resp. 30).
    func isDone(to: Int) -> Bool {
        let hi = max(me, opp), diff = abs(me - opp)
        let cap = to == 15 ? 21 : 30
        return (hi >= to && diff >= 2) || hi == cap
    }
}

struct PointEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: PointKind
    var reason: String?
    /// Setnummer, med början på 1.
    var game: Int
    var time: Date
    /// Ställningen i setet efter poängen.
    var me: Int
    var opp: Int
}

struct Match: Codable, Identifiable, Hashable {
    var id: String
    var opponent: String
    var round: String
    var to: Int
    var created: Date
    var games: [GameScore]
    var events: [PointEvent]
    var firstServer: Side?

    var game: GameScore { games[games.count - 1] }

    func events(inGame n: Int) -> [PointEvent] { events.filter { $0.game == n } }

    /// Vem som servar först i ett set (index från 0). Vinnaren av förra setet servar först.
    func serverAtStart(ofGame gi: Int) -> Side? {
        if gi == 0 { return firstServer }
        guard gi - 1 < games.count else { return nil }
        let pg = games[gi - 1]
        return pg.me > pg.opp ? .me : .opp
    }

    /// Vem som servade vid varje poäng, i samma ordning som `events`.
    func servers() -> [Side?] {
        var out: [Side?] = []
        var lastGame = 0
        var srv: Side? = nil
        for e in events {
            if e.game != lastGame {
                srv = serverAtStart(ofGame: e.game - 1)
                lastGame = e.game
            }
            out.append(srv)
            srv = e.kind == .won ? .me : .opp
        }
        return out
    }

    var currentServer: Side? {
        let gi = games.count - 1
        if let last = events.last(where: { $0.game == gi + 1 }) {
            return last.kind == .won ? .me : .opp
        }
        return serverAtStart(ofGame: gi)
    }

    var setsWon: (me: Int, opp: Int) {
        let done = games.filter { $0.isDone(to: to) }
        return (done.filter { $0.me > $0.opp }.count, done.filter { $0.opp > $0.me }.count)
    }
}

struct AppState: Codable {
    var player = "Douglas"
    var reasons = Reason.defaults
    var matches: [Match] = []
    var currentId: String?
    var lastTo = 15

    /// Lägger till standardorsaker som saknas (om nya har tillkommit i en uppdatering).
    mutating func migrate() {
        for r in Reason.defaults where !reasons.contains(where: { $0.id == r.id }) {
            reasons.append(r)
        }
    }
}
