import SwiftUI

/// Den svarta resultattavlan högst upp – "planen".
struct ScoreboardView: View {
    @Environment(Store.self) private var store
    let onNewMatch: () -> Void
    let onShowMatches: () -> Void

    var body: some View {
        let m = store.current
        let g = m?.game ?? GameScore()
        let srv = m?.currentServer

        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(height: 40)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Askim Badminton Club")

                HStack(spacing: 8) {
                    Button { store.step(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 28, height: 24)
                    }
                    .buttonStyle(OutlineOnDarkStyle())
                    .disabled(!store.canStep(-1))
                    .opacity(store.canStep(-1) ? 1 : 0.3)
                    .accessibilityLabel("Föregående match")

                    Button(action: onShowMatches) {
                        Text(store.matchLabel)
                            .underline()
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityHint("Visa alla matcher")

                    Button { store.step(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 28, height: 24)
                    }
                    .buttonStyle(OutlineOnDarkStyle())
                    .disabled(!store.canStep(1))
                    .opacity(store.canStep(1) ? 1 : 0.3)
                    .accessibilityLabel("Nästa match")

                    Button("Ny match", action: onNewMatch)
                        .buttonStyle(OutlineOnDarkStyle())
                }
                .font(.subheadline)

                HStack(spacing: 0) {
                    side(name: store.state.player, isMe: true, points: g.me, serving: srv == .me)
                    Rectangle().fill(.white.opacity(0.75)).frame(width: 2)
                    side(name: m?.opponent ?? "Motståndare", isMe: false, points: g.opp, serving: srv == .opp)
                }
                .fixedSize(horizontal: false, vertical: true)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.75), lineWidth: 2))
                .padding(.top, 2)

                if let m {
                    HStack(spacing: 10) {
                        ForEach(Array(m.games.enumerated()), id: \.offset) { i, x in
                            let isCur = i == m.games.count - 1
                            Text("Set \(i + 1): \(x.me)–\(x.opp)")
                                .monospacedDigit()
                                .fontWeight(isCur ? .semibold : .regular)
                                .underline(isCur)
                                .opacity(isCur ? 1 : 0.85)
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)

            Theme.red.frame(height: 5)
        }
        .foregroundStyle(.white)
        .background(Theme.court.ignoresSafeArea(edges: .top))
    }

    private func side(name: String, isMe: Bool, points: Int, serving: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                if isMe {
                    PlayerAvatar(name: name, size: 28)
                }
                Text(name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            }
            .frame(height: 30)
            Text("\(points)")
                .font(.scoreboard(60))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: points)
            Text("Servar")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 18)
                .background(Capsule().fill(Theme.red))
                .opacity(serving ? 1 : 0)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(points)\(serving ? ", servar" : "")")
    }
}
