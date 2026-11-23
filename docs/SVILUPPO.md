# Sviluppo

IDE C è un'app nativa per macOS in Swift + AppKit. Niente Xcode e niente dipendenze:
basta `xcode-select --install` (clang e swiftc).

## Struttura

```
Sorgenti/            il codice dell'app
Risorse/
  Info.plist         nome, versione, tipi di file che apre
  icona.swift        disegna l'icona (squircle grigio scuro come il Terminale, C bianca)
  DMG/
    sfondo-dmg.swift disegna lo sfondo della finestra del DMG (nero, stelline, aloni, freccia)
    dmg.py           posizione delle icone nel DMG (deve combaciare con lo sfondo)
Script/
  compila.sh         costruisce l'app in ~/Applications
  crea-dmg.sh        costruisce il DMG e, con --carica, la release su GitHub
  pubblica.sh        salva e carica il codice su GitHub
docs/                questa pagina e le immagini del README
CHANGELOG.md         le novità di ogni versione (diventano il testo della release)
```

### I sorgenti
- `main.swift` — avvio e menu
- `Snippet.swift` — **le scorciatoie**, divise in sezioni: per aggiungerne una copia una riga e ricompila
- `Legenda.swift` — la legenda (⌘K): ricerca, sezioni, schede con anteprima; clic = inserisci
- `Editor.swift` — editor: colori del codice, numeri di riga, riga corrente, Tab/Invio, chiusura automatica, impostazioni
- `Albero.swift` — albero dei file: cartelle, operazioni, trascinamento, aggiornamento automatico (FSEvents)
- `Tema.swift` — i colori (JetBrains «Dark» della New UI e «IntelliJ Light»), seguono l'aspetto del Mac
- `Finestra.swift` — finestra, barra in alto, colonna dei file, console, errori cliccabili
- `Esecuzione.swift` — compila con clang ed esegue il programma in un terminale finto (pty)
- `FinestraImpostazioni.swift` — Impostazioni (⌘,)
- `Documento.swift` — apri/salva (salvataggio automatico, versioni, schede: li fa macOS)

## Costruire l'app

```
Script/compila.sh                # solo Apple Silicon, più veloce: per provare
Script/compila.sh --universale   # Apple Silicon + Intel
```

Crea `~/Applications/IDE C.app`. I sorgenti vengono copiati in una cartella temporanea prima di compilare
(Syncthing a volte li tocca mentre `swiftc` li legge).

## Pubblicare una versione

1. Alza la versione in `Risorse/Info.plist` (`CFBundleShortVersionString` e `CFBundleVersion`).
2. Aggiungi in cima a `CHANGELOG.md` la sezione `## <versione>` con le novità.
3. Carica il codice: `Script/pubblica.sh "Versione X.Y"`.
4. Crea DMG e release: `Script/crea-dmg.sh --carica`.

Il DMG si chiama sempre `IDE-C.dmg`, così il link
`https://github.com/Dariooone/ide-c/releases/latest/download/IDE-C.dmg` del README scarica sempre l'ultima versione.
Il testo della release è la sezione del CHANGELOG più le istruzioni di installazione e lo SHA-256 del DMG.

La finestra del DMG la prepara `dmgbuild` (Python), che lo script installa da solo la prima volta in
`~/Library/Caches/IDE C/strumenti`. Il DMG resta anche in `~/Documents/Progetti/IDE-C.dmg`.

L'app è firmata solo localmente (ad hoc), non da Apple: per questo al primo avvio su un altro Mac
serve «Apri comunque». Toglierlo richiede un Apple Developer ID (99 $/anno) e la notarizzazione.

## Git

I dati di git stanno in `~/Documents/Progetti/ide-c.git`, fuori dalla cartella del codice:
la cartella è dentro un vault sincronizzato con Syncthing e non deve contenere `.git`.
`Script/pubblica.sh` imposta `GIT_DIR` da solo; per altri comandi git:

```
export GIT_DIR=~/Documents/Progetti/ide-c.git
```

## Dove finiscono le cose
- Programmi nuovi: si propongono in `~/Documents/Programmi C` (si può salvare ovunque).
- Eseguibili compilati: `~/Library/Caches/IDE C/` (cancellati quando chiudi la finestra).
- Compilazione: `clang -std=<scelto nelle Impostazioni> [-Wall] [-pedantic] … -lm` (di base C11 con -Wall).
