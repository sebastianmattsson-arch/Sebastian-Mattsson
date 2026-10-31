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
- **Livescore för familjen** (sändningsikonen överst): slå på delning, så skickas ställningen till iCloud efter varje poäng. Familjen öppnar en **länk i webbläsaren** (ingen app behövs) eller skriver in koden i Poänglogg-appen, och ser poäng, set, serve, de senaste poängen, matchförlopp och dagens matcher, och vyn uppdateras var 10:e sekund
- Mörkt läge, iPhone och iPad. Matcherna sparas lokalt på telefonen. Bara livescoren skickas till iCloud, och bara när delningen är på.

Ej med (än) jämfört med webbversionen: *Claude-analysen av matchen*.

## Kör appen på din iPhone

Du behöver en Mac med **Xcode 16 eller senare** (gratis i App Store).

1. Klona repot och öppna `PoangLogg/PoangLogg.xcodeproj` i Xcode.
2. Klicka på projektet **PoangLogg** → fliken **Signing & Capabilities** → välj ditt Apple-ID under **Team** (lägg till via *Xcode → Settings → Accounts* om det saknas). Ändra vid behov **Bundle Identifier** till något unikt, t.ex. `se.dittnamn.poanglogg`.
3. Anslut iPhonen med kabel, välj den högst upp i Xcode och tryck **▶ Run**.
4. **Spelarbild (valfritt):** dra in en kvadratisk bild på Douglas i `Assets.xcassets` och döp den till `Player`. Utan bild visas initialen. Bilden ignoreras av git eftersom repot är publikt.
5. Första gången: på iPhonen, gå till *Inställningar → Integritet och säkerhet → Utvecklarläge* och slå på det, och lita på utvecklaren under *Inställningar → Allmänt → VPN och enhetshantering*.

Med ett gratis Apple-ID fungerar appen i 7 dagar innan den måste installeras om från Xcode. Med **Apple Developer Program** (99 USD/år) håller den i ett år, och du kan dela den med familjen via **TestFlight** eller lägga upp den i App Store (*Product → Archive* i Xcode).

## TestFlight utan Mac

Workflowen `.github/workflows/testflight.yml` bygger, signerar och laddar upp appen till TestFlight på GitHubs Mac-maskiner. Allt nedan görs i en webbläsare (dator eller telefon).

### Engångsinställning

1. **Gå med i Apple Developer Program** på <https://developer.apple.com/programs/> (99 USD/år). Godkännandet kan ta upp till ett par dygn.
2. **Hitta ditt Team ID**: <https://developer.apple.com/account> → *Membership details* → *Team ID* (10 tecken).
3. **Registrera iCloud-container och Bundle ID** på <https://developer.apple.com/account/resources/identifiers>:
   - **+** → *iCloud Containers* → identifier `iCloud.com.sebastianmattsson.poanglogg`.
   - **+** → *App IDs* → *App* → Bundle ID (explicit) `com.sebastianmattsson.poanglogg`. Bocka i **iCloud** under *Capabilities*, välj *Include CloudKit support*, tryck *Edit/Configure* och välj containern ovan.
4. **Skapa appen i App Store Connect**: <https://appstoreconnect.apple.com> → *Appar* → **+** → *Ny app*. Plattform iOS, namn t.ex. *Poänglogg Askim* (namnet måste vara unikt i App Store), språk svenska, välj Bundle ID från steg 3, SKU t.ex. `poanglogg`.
5. **Skapa en API-nyckel**: App Store Connect → *Användare och åtkomst* → *Integrationer* → *App Store Connect API* → *Teamnycklar* → **+**. Namn `GitHub`, åtkomst **Admin** (krävs för att signeringen ska kunna skapa certifikat automatiskt). Notera **Issuer ID** och **Key ID** och ladda ner `.p8`-filen (går bara en gång).
6. **Lägg in secrets på GitHub**: repot → *Settings* → *Secrets and variables* → *Actions* → *New repository secret*:

   | Namn | Värde |
   |---|---|
   | `APPLE_TEAM_ID` | Team ID från steg 2 |
   | `ASC_ISSUER_ID` | Issuer ID från steg 5 |
   | `ASC_KEY_ID` | Key ID från steg 5 |
   | `ASC_KEY_P8` | Hela innehållet i `.p8`-filen, inklusive raderna `-----BEGIN PRIVATE KEY-----` och `-----END PRIVATE KEY-----` |
   | `PLAYER_PHOTO_BASE64` | *(valfritt)* spelarbilden som base64-text. Den hålls hemlig och läggs bara in vid bygget |

   Vill du använda ett annat Bundle ID: lägg till det som **variable** (fliken *Variables*) med namnet `BUNDLE_ID`.

7. **Förbered livescoren i CloudKit** (behövs för att livescoren ska fungera i TestFlight-byggen): <https://icloud.developer.apple.com> → *CloudKit Database* → välj containern → miljö **Development**:
   - *Schema → Record Types* → **+** → namn `LiveScore`. Lägg till fälten `payload` (typ *String*) och `updated` (typ *Date/Time*). Spara.
   - Välj *Deploy Schema Changes…* och sedan *Deploy* till **Production**.

   Publika databasen gör att alla med appen kan läsa en livescore med rätt kod, men bara den som skapade den kan ändra den.

8. **Webbsidan för familjen** (GitHub Pages):
   - CloudKit Console → containern → *API Access/Tokens & Keys* → **New API Token**. Namn `Webb`, *Allowed Origins*: `https://sebastianmattsson-arch.github.io`. Kopiera tokenen.
   - GitHub → *Settings* → *Secrets and variables* → *Actions* → fliken **Variables** → `CLOUDKIT_API_TOKEN` = tokenen. Tokenen syns i webbsidans källkod. Det är normalt för CloudKit på webben, eftersom den bara ger läsrätt till livescoren.
   - GitHub → *Settings* → *Pages* → *Source*: **GitHub Actions**.
   - *Actions* → **Livescore-webbsida** → *Run workflow*. Sidan finns sedan på <https://sebastianmattsson-arch.github.io/Sebastian-Mattsson/> och länken med kod skickas från appen.

### Skicka ett nytt bygge

GitHub → *Actions* → **TestFlight** → **Run workflow**. Efter ca 10 minuter för bygget och 5–15 minuter bearbetning hos Apple syns bygget i App Store Connect under *TestFlight*.

### Installera på iPhonen

1. App Store Connect → appen → *TestFlight* → *Interna testare* → **+** → skapa en grupp och lägg till dig själv (och familjen, de måste läggas till som användare under *Användare och åtkomst*). Bjud in externa testare via *Externa testare*. Då granskar Apple första bygget, vilket brukar ta ungefär ett dygn.
2. Installera **TestFlight** från App Store på iPhonen, öppna inbjudan i mejlet och tryck **Installera**.

Ett TestFlight-bygge fungerar i 90 dagar. Kör workflowen igen för att få ett nytt.

## Struktur

```
PoangLogg/
  PoangLogg.xcodeproj
  Info.plist             tillägg till Info.plist (exportkryptering)
  PoangLogg.entitlements iCloud/CloudKit för livescoren
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
    Live.swift           livescore-data och CloudKit
    LiveViews.swift      livescore-vyn, följ med kod, livescore-inställningar
web/
  index.html             livescore-webbsidan (publiceras med GitHub Pages)
    Assets.xcassets      appikon, klubblogga (spelarbild läggs till lokalt)
```

GitHub Actions: `ios-build.yml` bygger appen vid varje push för att kontrollera att koden kompilerar. `testflight.yml` laddar upp till TestFlight när du kör den manuellt. `pages.yml` publicerar livescore-webbsidan.
