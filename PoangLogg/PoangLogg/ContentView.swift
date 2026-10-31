import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store

    enum Tab: Hashable { case log, stats }

    @State private var tab: Tab = .log
    @State private var showNewMatch = false
    @State private var showMatches = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            ScoreboardView(onNewMatch: { showNewMatch = true },
                           onShowMatches: { showMatches = true })

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
