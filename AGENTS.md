# AGENTS.md — Note per assistenti AI (Dominator)

Guida operativa per chiunque (umano o AI) lavori su questo progetto. Leggere prima di modificare.

## Cos'è
App nativa **SwiftUI multipiattaforma** (macOS 14+ / iOS 17+ / iPadOS) che genera PDF
stampabili di *fiducial domino* per il CNC **Shaper Origin**. È un **porting in Swift** della
web app Python/Flask [berncodes/pyDominoPDF](https://github.com/berncodes/pyDominoPDF).

> ⚖️ **Licenza**: l'originale è **GPLv3**. Questo è un lavoro derivato → va mantenuto e
> distribuito sotto **GPLv3**. Tenerne conto se si aggiungono dipendenze o si pubblica.

## Naming (attenzione, è incoerente di proposito)
- **Display name / prodotto / bundle**: `Dominator` (`Dominator.app`, `CFBundleName` e
  `CFBundleDisplayName` = Dominator).
- **Target Xcode, cartella sorgenti, nome progetto**: ancora `DominoPDF` (`DominoPDF.xcodeproj`,
  cartella `DominoPDF/`). Solo interno, invisibile all'utente.
- **Bundle identifier**: `com.belleri.DominoPDF`.
- Il menu bar di macOS usa `CFBundleName` (NON `CFBundleDisplayName`): per rinominare l'app
  serve cambiare `PRODUCT_NAME`, non solo il display name.

## Build & Run (verificato funzionante)
Niente team di firma configurato → si compila/lancia con **firma ad-hoc**:
```bash
cd "/Users/micky/Sync/AI/Home/Domino project"
xcodebuild -project DominoPDF.xcodeproj -scheme DominoPDF -sdk macosx \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES build
open "build/Build/Products/Debug/Dominator.app"
```
- Solo verifica di compilazione: aggiungere `CODE_SIGNING_ALLOWED=NO`.
- iOS: `-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'`.
- Dopo aver cambiato `PRODUCT_NAME` o gli asset/icone, fare `clean build` (o `rm -rf build`).

## Struttura
```
DominoPDF/
  DominoPDFApp.swift          @main
  Models/
    DominoConfig.swift        parametri + enum DominoUnit, PaperSize (+ conversioni mm)
    DominoGenerator.swift     CUORE: valori validi + rendering PDF (Core Graphics)
    Printer.swift             stampa cross-platform
    PDFFile.swift             FileDocument per export
  Views/
    ContentView.swift         NavigationSplitView (impostazioni | anteprima) + toolbar
    SettingsForm.swift        Form con sezioni collassabili
    PDFKitView.swift          anteprima (NS/UIViewRepresentable)
  Assets.xcassets/AppIcon.appiconset/   icone (vedi Tools/make_icon.swift)
Tools/make_icon.swift         genera le icone (quadrato nero, 3 punti bianchi a L)
```

## Progetto Xcode (pbxproj scritto a mano!)
- `objectVersion = 77`, usa **PBXFileSystemSynchronizedRootGroup**: i file .swift dentro
  `DominoPDF/` vengono inclusi **automaticamente**. Per aggiungere un file basta crearlo nella
  cartella — **non serve editare il pbxproj**. (Aprendo in Xcode si sincronizza da solo.)
- Gli ID degli oggetti sono fittizi/leggibili (`AB0000...A1` ecc.): mantenere lo schema se si
  aggiungono oggetti a mano.
- Esiste uno scheme condiviso `DominoPDF.xcscheme` (BuildableName = `Dominator.app`).

## Logica di dominio (DominoGenerator.swift)
- **452 domino validi** generati da regole a 12 bit (riga1 = 6 bit alti, riga2 = 6 bit bassi):
  totale pip = 6, no palindromi a 12 bit, no rotazioni duplicate. Verificato identico alla
  lista hardcoded del Python (stessi primi/ultimi valori).
- **Geometria** del domino in pollici (1.7×0.5) moltiplicata per `unitScale` (inch=1, mm=25.4,
  cm=2.54) → fisicamente costante a prescindere dall'unità.
- **Coordinate**: il contesto PDF di Core Graphics ha origine **in basso a sinistra, y verso
  l'alto** — coincide con PyX, nessun flip necessario. Il testo Core Text risulta dritto.
- **Punti PDF**: il contesto è scalato di `pointsPerUnit` (inch=72) → si disegna in "unità".
- **Correzione di scala**: fattore = `stated / measured` (default uguali ⇒ 1.0). Applicata come
  ulteriore `scaleBy(xSF, ySF)` sul contenuto della pagina (non sul mediaBox).
- **Linee di calibrazione**: due linee di quota "spezzate" (stile disegno tecnico) sui bordi
  inferiore/sinistro, con la misura (font **Menlo** monospace) in asse dentro lo spazio della
  linea. Niente tacche alle estremità (creavano ambiguità interno/esterno).

## Insidie SwiftUI già incontrate (NON re-introdurle)
1. **`NSAttributedString.Key.foregroundColor`/`.font` non esistono** senza importare AppKit/UIKit.
   In `DominoGenerator` si usano le chiavi Core Text (`kCTFontAttributeName`,
   `kCTForegroundColorAttributeName`) per restare indipendenti dalla UI.
2. **Picker `.segmented` con binding calcolato**: su macOS non committava in modo affidabile la
   mutazione → l'orientamento Portrait/Landscape è ora un **Button** che scambia W/H. Evitare
   pickers con `Binding(get:set:)` che mutano stato derivato.
3. **`Section(isExpanded:)` NON ha una variante con footer**: usare
   `Section("Titolo", isExpanded: $flag)` e mettere l'eventuale nota come `Text` dentro il
   contenuto.
4. **`swap(&config.a, &config.b)`** su due proprietà dello stesso `@Binding` calcolato → errore
   di aliasing. Usare una variabile temporanea.
5. Le dimensioni di pagina **non si riconvertono** al cambio di unità (comportamento ereditato
   dall'originale). Il menu Paper size applica i valori nell'unità corrente.

## Icone (Tools/make_icon.swift)
- Genera due master 1024px: `fullBleed=true` per iOS (il sistema arrotonda), `false` per macOS
  (squircle nero con margine trasparente). Poi si ridimensiona con `sips` nei file
  `mac_16..1024.png` + `icon_ios_1024.png`, già referenziati da `AppIcon.appiconset/Contents.json`.
- Rigenerare: `swift Tools/make_icon.swift`, copiare i PNG, lanciare i `sips`, rebuild.
- ⚠️ **Cache icone del Dock**: dopo il rebuild il Dock può mostrare la vecchia icona. Il bundle
  è corretto (verificabile con `NSWorkspace.shared.icon(forFile:)`). Forzare con
  `lsregister -f <app>` + `killall Dock`.

## Come verificare il PDF senza UI
Concatenare i due file Models e aggiungere un main che chiama `DominoGenerator.makePDF`, poi
renderizzare una pagina a PNG con PDFKit e ispezionarla. (Pattern usato in tutta la cronologia.)
```bash
cat DominoPDF/Models/DominoConfig.swift DominoPDF/Models/DominoGenerator.swift > /tmp/t.swift
# + main che scrive un PDF, poi PDFDocument -> NSBitmapImageRep -> PNG
swift /tmp/t.swift
```

## Stato / possibili migliorie
- Icona non aggiornata col nuovo nome (è solo grafica, non contiene testo: ok così).
- Conversione automatica dimensioni al cambio unità: non implementata (di proposito).
- Rinomina interna completa a "Dominator" (target/cartella/identifier): non fatta, puramente
  estetica e invasiva.
- Niente persistenza delle impostazioni tra sessioni (l'originale usava cookie).
