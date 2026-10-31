import SwiftUI
import UIKit

/// Livescore som familjen ser den.
struct LiveScoreView: View {
    let doc: LiveDoc?
    var message: String? = nil
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(metaText)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)

                    if let doc, let m = currentMatch, doc.sets.contains(where: { !$0.isEmpty }) {
                        SectionTitle(title: "Matchförlopp")
                        HStack(spacing: 14) {
                            legendDot(Theme.win, "\(doc.player) vann")
                            legendDot(Theme.own, "\(doc.player) tappade")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                        VStack(spacing: 8) {
                            ForEach(Array(doc.sets.enumerated()), id: \.offset) { i, seq in
                                if !seq.isEmpty {
                                    LiveFlowChart(seq: seq, game: i + 1, player: doc.player, opponent: m.opponent)
                                }
                            }
                        }
                    }

                    if let doc, !doc.matches.isEmpty {
                        SectionTitle(title: "Dagens matcher")
                        matchList(doc)
                    }

                    if let doc {
                        Text("Uppdaterad \(doc.updated.formatted(date: .omitted, time: .shortened)). Sidan uppdateras av sig själv.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 40)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
    }

    // MARK: - Beräkningar

    private var currentMatch: LiveDoc.LiveMatch? {
        guard let doc, !doc.matches.isEmpty else { return nil }
        return doc.matches.first { $0.id == doc.currentId } ?? doc.matches.last
    }

    private var sets: (me: Int, opp: Int) {
        guard let m = currentMatch else { return (0, 0) }
        let done = m.games.filter { $0.isDone(to: m.to) }
        return (done.filter { $0.me > $0.opp }.count, done.filter { $0.opp > $0.me }.count)
    }

    private var finished: Bool { sets.me >= 2 || sets.opp >= 2 }

    private var metaText: String {
        if let message { return message }
        guard let m = currentMatch else { return "Ingen match har startat än." }
        return m.round
    }

    private var badge: (text: String, on: Bool) {
        guard let doc, let m = currentMatch else { return ("Livescore", false) }
        if finished {
            let winner = sets.me > sets.opp ? doc.player : m.opponent
            return ("\(winner) vann \(max(sets.me, sets.opp))–\(min(sets.me, sets.opp))", false)
        }
        if m.games.contains(where: { !$0.isEmpty }) { return ("Pågår · set \(m.games.count)", true) }
        return ("Nästa match", false)
    }

    // MARK: - Delar

    private var header: some View {
        let m = currentMatch
        let g = m?.games.last ?? GameScore()
        let server = (!finished && m?.id == doc?.currentId) ? doc?.server : nil
        let player = doc?.player ?? ""

        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                ZStack {
                    Image("Logo")
                        .resizable().renderingMode(.template).scaledToFit()
                        .frame(height: 40)
                        .accessibilityLabel("Askim Badminton Club")
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(OutlineOnDarkStyle())
                        .accessibilityLabel("Stäng")
                    }
                }

                Text(badge.text)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 2)
                    .background(Capsule().fill(badge.on ? Theme.red : Color(hex: 0x4A4A4A)))

                HStack(alignment: .bottom, spacing: 6) {
                    person(name: player.isEmpty ? "–" : player, isMe: true,
                           points: g.me, serving: server == .me)
                    Text("–").font(.scoreboard(44)).opacity(0.5).padding(.bottom, 30)
                    person(name: m?.opponent ?? "–", isMe: false,
                           points: g.opp, serving: server == .opp)
                }
                .padding(.top, 4)

                if let m {
                    HStack(spacing: 10) {
                        ForEach(Array(m.games.enumerated()), id: \.offset) { i, x in
                            let isCur = i == m.games.count - 1 && !finished
                            Text("Set \(i + 1): \(x.me)–\(x.opp)")
                                .monospacedDigit()
                                .fontWeight(isCur ? .semibold : .regular)
                                .underline(isCur)
                        }
                    }
                    .font(.subheadline)
                }

                if let doc, !finished, !doc.recent.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(doc.recent.enumerated()), id: \.offset) { _, won in
                            Circle().fill(won ? Color.white : Theme.red).frame(width: 11, height: 11)
                        }
                    }
                    .padding(.top, 4)
                    .accessibilityLabel("Senaste poängen")
                }
            }
            .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)

            Theme.red.frame(height: 5)
        }
        .foregroundStyle(.white)
        .background(Theme.court.ignoresSafeArea(edges: .top))
    }

    private func person(name: String, isMe: Bool, points: Int, serving: Bool) -> some View {
        VStack(spacing: 6) {
            if isMe {
                PlayerAvatar(name: name, size: 64, ring: 3)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 28, weight: .bold).width(.condensed))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color(hex: 0x2A2A2A)))
                    .overlay(Circle().stroke(Color(hex: 0x555555), lineWidth: 3))
            }
            Text(name).fontWeight(.semibold).lineLimit(1)
            Text("\(points)")
                .font(.scoreboard(76))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: points)
            Text("Servar")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 18)
                .background(Capsule().fill(Theme.red))
                .opacity(serving ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text)
        }
    }

    private func matchList(_ doc: LiveDoc) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.rule)
            ForEach(doc.matches) { x in
                let score = x.games.filter { !$0.isEmpty }.map { "\($0.me)–\($0.opp)" }.joined(separator: ", ")
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mot \(x.opponent)").fontWeight(x.id == currentMatch?.id ? .bold : .regular)
                        if !x.round.isEmpty {
                            Text(x.round).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 10)
                    Text(score.isEmpty ? "Ej spelad" : score)
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
                .font(.system(size: 15))
                .padding(.vertical, 8).padding(.horizontal, 2)
                Divider().overlay(Theme.rule)
            }
        }
    }
}

/// Förenklad förloppsgraf för livescoren (vann/tappade, utan orsaker).
struct LiveFlowChart: View {
    let seq: [Bool]
    let game: Int
    let player: String
    let opponent: String

    var body: some View {
        var me = 0, op = 0
        let diffs: [Int] = [0] + seq.map { won in
            if won { me += 1 } else { op += 1 }
            return me - op
        }
        let score = "\(seq.filter { $0 }.count)–\(seq.filter { !$0 }.count)"

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Set \(game)").fontWeight(.semibold)
                Spacer()
                Text(score).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .font(.system(size: 15))
            .padding(.horizontal, 4)

            Canvas { ctx, size in
                let pl: CGFloat = 26, pr: CGFloat = 10, pt: CGFloat = 10, pb: CGFloat = 10
                let plotH = size.height - pt - pb
                let maxAbs = max(3, diffs.map(abs).max() ?? 0)
                let n = CGFloat(max(10, seq.count))
                func x(_ i: Int) -> CGFloat { pl + (size.width - pl - pr) * CGFloat(i) / n }
                func y(_ d: Int) -> CGFloat { pt + plotH / 2 - CGFloat(d) / CGFloat(maxAbs) * plotH / 2 }

                ctx.fill(Path(CGRect(x: pl, y: pt, width: size.width - pl - pr, height: plotH / 2)),
                         with: .color(Theme.winSoft.opacity(0.6)))
                let ax = Font.system(size: 10)
                ctx.draw(Text("\(player) leder").font(ax).foregroundStyle(Theme.muted),
                         at: CGPoint(x: pl + 4, y: pt + 2), anchor: .topLeading)
                ctx.draw(Text("\(opponent) leder").font(ax).foregroundStyle(Theme.muted),
                         at: CGPoint(x: pl + 4, y: pt + plotH - 2), anchor: .bottomLeading)
                ctx.draw(Text("+\(maxAbs)").font(ax).foregroundStyle(Theme.muted),
                         at: CGPoint(x: pl - 6, y: y(maxAbs)), anchor: .trailing)
                ctx.draw(Text("0").font(ax).foregroundStyle(Theme.muted),
                         at: CGPoint(x: pl - 6, y: y(0)), anchor: .trailing)
                ctx.draw(Text("−\(maxAbs)").font(ax).foregroundStyle(Theme.muted),
                         at: CGPoint(x: pl - 6, y: y(-maxAbs)), anchor: .trailing)

                var zero = Path()
                zero.move(to: CGPoint(x: pl, y: y(0)))
                zero.addLine(to: CGPoint(x: size.width - pr, y: y(0)))
                ctx.stroke(zero, with: .color(Theme.muted), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                var line = Path()
                for (i, d) in diffs.enumerated() {
                    let p = CGPoint(x: x(i), y: y(d))
                    if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
                }
                ctx.stroke(line, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                for (i, won) in seq.enumerated() {
                    let c = CGPoint(x: x(i + 1), y: y(diffs[i + 1]))
                    let dot = Path(ellipseIn: CGRect(x: c.x - 3.6, y: c.y - 3.6, width: 7.2, height: 7.2))
                    ctx.fill(dot, with: .color(won ? Theme.win : Theme.own))
                    ctx.stroke(dot, with: .color(Theme.surface), lineWidth: 1.2)
                }
            }
            .frame(height: 130)
            .accessibilityLabel("Ledning poäng för poäng i set \(game), \(score)")
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.rule, lineWidth: 1.5))
    }
}

/// Följer en livescore via kod och hämtar nytt var 10:e sekund.
struct FollowView: View {
    let code: String
    let onClose: () -> Void

    @State private var doc: LiveDoc?
    @State private var message: String? = "Hämtar livescore …"

    var body: some View {
        LiveScoreView(doc: doc, message: message, onClose: onClose)
            .task(id: code) {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: .seconds(10))
                }
            }
    }

    private func load() async {
        do {
            if let d = try await LiveService.fetch(code: code) {
                doc = d
                message = nil
            } else {
                doc = nil
                message = "Ingen livescore med koden \(code) än. Kontrollera koden – sidan försöker igen av sig själv."
            }
        } catch {
            message = doc == nil
                ? "Livescoren går inte att hämta just nu. Försöker igen …"
                : "Tappade kontakten – visar senaste ställningen och försöker igen."
        }
    }
}

/// Inställningar för livescore: dela egen eller följ någon annans.
struct LiveSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPreview: () -> Void
    let onFollow: (String) -> Void

    @State private var followInput = ""

    var body: some View {
        let followCode = LiveService.normalize(followInput)

        NavigationStack {
            Form {
                Section {
                    Toggle("Dela livescore", isOn: Binding(
                        get: { store.state.liveEnabled },
                        set: { store.setLiveEnabled($0) }))

                    if store.state.liveEnabled, let code = store.state.liveCode {
                        LabeledContent("Kod") {
                            Text(code)
                                .font(.title2.monospaced().weight(.bold))
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                        }
                        ShareLink(item: store.liveInvite) {
                            Label("Skicka länken till familjen", systemImage: "square.and.arrow.up")
                        }
                        if let link = LiveService.webLink(code: code) {
                            Button {
                                UIPasteboard.general.url = link
                                store.show("Länken kopierad")
                            } label: {
                                Label("Kopiera länk", systemImage: "link")
                            }
                        }
                        Button {
                            dismiss()
                            onPreview()
                        } label: {
                            Label("Visa som familjen ser den", systemImage: "eye")
                        }
                        if let status = store.liveStatus {
                            Text(status).font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                } header: {
                    Text("Livescore för familjen")
                } footer: {
                    Text("Ställningen skickas till iCloud efter varje poäng. Familjen öppnar länken i webbläsaren, ingen app behövs. Med Poänglogg-appen går det också att följa med koden. Du behöver vara inloggad på iCloud.")
                }

                Section {
                    TextField("Kod, t.ex. K7M2QX", text: $followInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    Button("Följ match") {
                        store.state.followCode = followCode
                        dismiss()
                        onFollow(followCode)
                    }
                    .disabled(followCode.count < 4)
                    if let saved = store.state.followCode {
                        Button("Fortsätt följa \(saved)") {
                            dismiss()
                            onFollow(saved)
                        }
                    }
                } header: {
                    Text("Följ någon annans match")
                }

                if store.state.liveEnabled {
                    Section {
                        Button("Byt kod", role: .destructive) { store.newLiveCode() }
                    } footer: {
                        Text("Den gamla koden slutar uppdateras. Skicka den nya koden till familjen.")
                    }
                }
            }
            .navigationTitle("Livescore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } }
            }
        }
    }
}
