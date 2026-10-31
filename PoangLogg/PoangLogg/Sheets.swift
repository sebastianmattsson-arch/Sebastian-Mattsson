import SwiftUI

struct NewMatchSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var opponent = ""
    @State private var round = ""
    @State private var to = 15

    var body: some View {
        NavigationStack {
            Form {
                Section("Motståndare") {
                    TextField("Namn eller klubb", text: $opponent)
                        .textInputAutocapitalization(.words)
                }
                Section("Omgång (valfritt)") {
                    TextField("T.ex. Pool A, kvartsfinal", text: $round)
                }
                Section {
                    Picker("Set spelas till", selection: $to) {
                        Text("15 poäng").tag(15)
                        Text("21 poäng").tag(21)
                    }
                }
            }
            .navigationTitle("Ny match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Starta match") {
                        store.newMatch(opponent: opponent.trimmingCharacters(in: .whitespaces),
                                       round: round.trimmingCharacters(in: .whitespaces), to: to)
                        store.show("Match startad")
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { to = store.state.lastTo }
        }
        .presentationDetents([.medium, .large])
    }
}

struct MatchesSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var toDelete: Match?

    var body: some View {
        NavigationStack {
            List {
                if store.state.matches.isEmpty {
                    Text("Inga matcher än. Tryck Ny match för att börja.")
                        .foregroundStyle(Theme.muted)
                }
                ForEach(Array(store.state.matches.enumerated().reversed()), id: \.element.id) { i, m in
                    Button {
                        store.select(m.id)
                        dismiss()
                    } label: {
                        row(i, m)
                    }
                    .foregroundStyle(Theme.ink)
                    .swipeActions {
                        Button("Radera", role: .destructive) { toDelete = m }
                    }
                }
            }
            .navigationTitle("Alla matcher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Stäng") { dismiss() } }
            }
            .confirmationDialog("Radera matchen mot \(toDelete?.opponent ?? "")?",
                                isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Radera", role: .destructive) {
                    if let m = toDelete { store.deleteMatch(m.id) }
                    toDelete = nil
                }
            }
        }
    }

    private func row(_ i: Int, _ m: Match) -> some View {
        let lost = m.events.filter { $0.kind == .lost }.count
        let when = m.created.formatted(.dateTime.day().month(.abbreviated).hour().minute()
            .locale(Locale(identifier: "sv_SE")))
        let sets = m.games.map { "\($0.me)–\($0.opp)" }.joined(separator: ", ")
        let isCur = m.id == store.state.currentId
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(i + 1). Mot \(m.opponent)" + (m.round.isEmpty ? "" : " – \(m.round)") + (isCur ? "  (visas nu)" : ""))
                .fontWeight(.semibold)
            Text("\(when) · \(sets) · \(lost) förlorade")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 2)
    }
}

struct SettingsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var newReason = ""
    @State private var newType: ReasonType = .own
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Spelarens namn") {
                    TextField("Namn", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    TextField("T.ex. Backhand-clear för kort", text: $newReason)
                    Picker("Typ", selection: $newType) {
                        ForEach(ReasonType.selectable) { Text($0.pickerLabel).tag($0) }
                    }
                } header: {
                    Text("Lägg till egen orsak")
                }

                let custom = store.state.reasons.filter(\.isCustom)
                if !custom.isEmpty {
                    Section {
                        ForEach(custom) { r in
                            VStack(alignment: .leading) {
                                Text(r.label)
                                Text(r.type.pickerLabel).font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { store.deleteReason(custom[i].id) }
                        }
                    } header: {
                        Text("Egna orsaker")
                    } footer: {
                        Text("Svep åt vänster för att ta bort. Redan loggade poäng behåller orsaken i loggen.")
                    }
                }

                Section {
                    Button("Radera all data", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Allt sparas bara på den här telefonen.")
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Radera alla matcher och egna orsaker?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Radera allt", role: .destructive) {
                    store.resetAll()
                    dismiss()
                }
            }
            .onAppear { name = store.state.player }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { store.state.player = n }
        let r = newReason.trimmingCharacters(in: .whitespaces)
        if !r.isEmpty { store.addReason(label: r, type: newType) }
        store.show("Sparat")
        dismiss()
    }
}
