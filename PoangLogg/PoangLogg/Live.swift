import CloudKit
import Foundation

/// Det som familjen ser – samma innehåll som livescoren i webbversionen.
struct LiveDoc: Codable, Equatable {
    struct LiveMatch: Codable, Equatable, Identifiable {
        var id: String
        var opponent: String
        var round: String
        var to: Int
        var games: [GameScore]
    }

    var player: String
    var updated: Date
    var currentId: String?
    var matches: [LiveMatch]
    /// De senaste poängen i pågående set, true = spelaren vann poängen.
    var recent: [Bool]
    /// Varje set i pågående match, poäng för poäng.
    var sets: [[Bool]]
    var server: Side?
}

extension AppState {
    func liveDoc() -> LiveDoc {
        let m = matches.first { $0.id == currentId }
        return LiveDoc(
            player: player,
            updated: .now,
            currentId: currentId,
            matches: matches.map {
                LiveDoc.LiveMatch(id: $0.id, opponent: $0.opponent, round: $0.round, to: $0.to, games: $0.games)
            },
            recent: m.map { m in Array(m.events(inGame: m.games.count).suffix(15).map { $0.kind == .won }) } ?? [],
            sets: m.map { m in m.games.indices.map { i in m.events(inGame: i + 1).map { $0.kind == .won } } } ?? [],
            server: m?.currentServer)
    }
}

/// Livescoren lagras i appens publika CloudKit-databas: en post per kod.
/// Alla kan läsa (även utan iCloud-konto), bara den som skapade posten kan ändra den.
enum LiveService {
    static let recordType = "LiveScore"

    /// Webbsidan där familjen följer via länk (GitHub Pages, mappen web/ i repot).
    static let webBase = "https://sebastianmattsson-arch.github.io/Sebastian-Mattsson/"

    static func webLink(code: String) -> URL? { URL(string: webBase + "?kod=" + code) }

    private static var db: CKDatabase { CKContainer.default().publicCloudDatabase }

    static func makeCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    static func normalize(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    static func publish(_ doc: LiveDoc, code: String) async throws {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: code))
        let json = try JSONEncoder().encode(doc)
        record["payload"] = String(decoding: json, as: UTF8.self)
        record["updated"] = doc.updated
        let (results, _) = try await db.modifyRecords(saving: [record], deleting: [],
                                                     savePolicy: .allKeys, atomically: false)
        if let result = results[record.recordID] { _ = try result.get() }
    }

    static func fetch(code: String) async throws -> LiveDoc? {
        do {
            let record = try await db.record(for: CKRecord.ID(recordName: code))
            guard let payload = record["payload"] as? String else { return nil }
            return try JSONDecoder().decode(LiveDoc.self, from: Data(payload.utf8))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    static func describe(_ error: Error) -> String {
        guard let ck = error as? CKError else { return "Livescoren kunde inte uppdateras just nu." }
        switch ck.code {
        case .notAuthenticated:
            return "Logga in på iCloud i telefonens Inställningar för att dela livescore."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "Ingen kontakt just nu – försöker igen vid nästa poäng."
        case .permissionFailure:
            return "Koden används redan av någon annan. Tryck Byt kod."
        default:
            return "Livescoren kunde inte uppdateras (\(ck.code.rawValue))."
        }
    }
}
