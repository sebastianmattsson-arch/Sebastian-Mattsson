# Poänglogg – Askim Badminton Club (iOS)

En riktig iPhone-app (SwiftUI) byggd från webbappen *Poänglogg*. Logga varje poäng i Douglas matcher med orsak, håll koll på serven och se statistik och matchförlopp.

## Det här finns i appen

- **Resultattavla** med poäng, set, vem som servar och bläddring mellan matcher
- **Logga**: "tappade" (eget fel / motståndaren vann den) och "vann" (motståndarens fel / egen vinnare), med räknare på varje knapp och en kort vibration vid tryck
- **Serve**: välj vem som servar först, sedan räknas serven ut för varje poäng (vinnaren av förra setet servar först i nästa)
- **Ångra senaste**, **Nästa set** (max tre set, set till 15 eller 21)
- **Statistik** för matchen, ett set eller hela turneringen: matchförlopp (tryck på en punkt), förlorade/vunna poäng per orsak, serve och mottagning
- **Dela / kopiera sammanfattning** (till Meddelanden, mejl, Anteckningar …)
- **Inställningar**: spelarens namn, egna orsaker (svep för att ta bort), radera all data
- Mörkt läge, iPhone och iPad. All data sparas lokalt på telefonen.

Ej med (än) jämfört med webbversionen: *Claude-analysen av matchen* och *livescore för familjen*. Båda kräver en server eller ett konto och kan läggas till senare.

## Kör appen på din iPhone

Du behöver en Mac med **Xcode 16 eller senare** (gratis i App Store).

1. Klona repot och öppna `PoangLogg/PoangLogg.xcodeproj` i Xcode.
2. Klicka på projektet **PoangLogg** → fliken **Signing & Capabilities** → välj ditt Apple-ID under **Team** (lägg till via *Xcode → Settings → Accounts* om det saknas). Ändra vid behov **Bundle Identifier** till något unikt, t.ex. `se.dittnamn.poanglogg`.
3. Anslut iPhonen med kabel, välj den högst upp i Xcode och tryck **▶ Run**.
4. **Spelarbild (valfritt):** dra in en kvadratisk bild på Douglas i `Assets.xcassets` och döp den till `Player`. Utan bild visas initialen. Bilden ignoreras av git eftersom repot är publikt.
5. Första gången: på iPhonen, gå till *Inställningar → Integritet och säkerhet → Utvecklarläge* och slå på det, och lita på utvecklaren under *Inställningar → Allmänt → VPN och enhetshantering*.

Med ett gratis Apple-ID fungerar appen i 7 dagar innan den måste installeras om från Xcode. Med **Apple Developer Program** (99 USD/år) håller den i ett år, och du kan dela den med familjen via **TestFlight** eller lägga upp den i App Store (*Product → Archive* i Xcode).

## Struktur

```
PoangLogg/
  PoangLogg.xcodeproj
  PoangLogg/
    PoangLoggApp.swift   appens start
    Models.swift         matcher, poäng, orsaker, serve- och setlogik
    Store.swift          sparar data (JSON i appens dokumentmapp) och alla åtgärder
    Theme.swift          färger (ljust/mörkt), typsnitt, knappstilar
    ContentView.swift    huvudvy med flikar och toast
    ScoreboardView.swift resultattavlan
    LogView.swift        loggningsfliken
    StatsView.swift      statistikfliken
    FlowChart.swift      matchförloppsgrafen
    Sheets.swift         Ny match, Alla matcher, Inställningar
    Assets.xcassets      appikon, klubblogga (spelarbild läggs till lokalt)
```

GitHub Actions (`.github/workflows/ios-build.yml`) bygger appen på en Mac vid varje push, så att man ser att koden kompilerar.
