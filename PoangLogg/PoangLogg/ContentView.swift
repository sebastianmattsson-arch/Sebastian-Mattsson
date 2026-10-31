import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store

    enum Tab: Hashable { case log, stats }

    @State private var tab: Tab = .log
    @State private var showNewMatch = false
    @State private var showMatches = false
    @State private var showSettings = false
    @State private var showLive = false
    @State private var pendingLive: LiveCover?
    @State private var liveCover: LiveCover?

    enum LiveCover: Identifiable, Equatable {
        case preview
        case follow(String)
        var id: String {
            switch self {
            case .preview: return "preview"
            case .follow(let code): return "follow-" + code
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreboardView(onNewMatch: { showNewMatch = true },
                           onShowMatches: { showMatches = true },
                           onLive: { showLive = true })

            Picker("Vy", selection: $tab) {
                Text("Logga").tag(Tab.log)
                Text("Statistik").tag(Tab.stats)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: 560)

            ScrollView {
                Group {
                    switch tab {
                    case .log: LogView()
                    case .stats: StatsView(onSettings: { showSettings = true })
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 40)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .overlay(alignment: .bottom) { ToastView() }
        .sheet(isPresented: $showNewMatch) { NewMatchSheet() }
        .sheet(isPresented: $showMatches) { MatchesSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showLive, onDismiss: {
            if let p = pendingLive {
                pendingLive = nil
                liveCover = p
            }
        }) {
            LiveSheet(onPreview: { pendingLive = .preview },
                      onFollow: { pendingLive = .follow($0) })
        }
        .fullScreenCover(item: $liveCover) { cover in
            switch cover {
            case .preview:
                LiveScoreView(doc: store.state.liveDoc(), onClose: { liveCover = nil })
            case .follow(let code):
                FollowView(code: code, onClose: { liveCover = nil })
            }
        }
        .onAppear {
            // Familjemedlemmar som bara följer: öppna livescoren direkt.
            if store.state.matches.isEmpty, let code = store.state.followCode {
                liveCover = .follow(code)
            }
        }
    }
}

struct ToastView: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let t = store.toast {
            Text(t.text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Theme.ink))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .transition(.opacity)
                .allowsHitTesting(false)
                .task(id: t.id) {
                    try? await Task.sleep(for: .seconds(2.2))
                    if store.toast?.id == t.id {
                        withAnimation { store.toast = nil }
                    }
                }
        }
    }
}
