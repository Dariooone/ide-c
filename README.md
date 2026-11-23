# IDE C

App nativa per macOS (Swift + AppKit) per scrivere, compilare ed eseguire programmi in C.
Niente completamento automatico né suggerimenti: solo **scorciatoie** (scrivi `main` e premi Tab).

## Costruire l'app
Serve solo `xcode-select --install` (clang e swiftc, niente Xcode).

```
./compila.sh
```

Crea `~/Applications/IDE C.app` (fuori dal vault). Dopo ogni modifica ai sorgenti si rilancia lo stesso comando.

## GitHub
Repo privata: https://github.com/Dariooone/ide-c
I dati di git stanno fuori dal vault, in `~/Documents/Progetti/ide-c.git` (così Syncthing non li copia sul server).
Per caricare le modifiche:

```
./pubblica.sh "cosa ho cambiato"
```

## DMG
```
./crea-dmg.sh            # crea ~/Documents/Progetti/IDE-C-<versione>.dmg
./crea-dmg.sh --carica   # e lo mette nella release su GitHub
```
La finestra del DMG ha uno sfondo nero con stelline ad asterisco, un alone di luce dietro le icone e la freccia verso Applicazioni: lo disegna `sfondo-dmg.swift`,
la disposizione delle icone è in `dmg.py` (le posizioni devono combaciare con lo sfondo). La finestra la prepara
`dmgbuild` (Python), installato la prima volta in `~/Library/Caches/IDE C/strumenti`.
La versione si prende da `Info.plist` (`CFBundleShortVersionString`): per una release nuova alzala lì.
L'app non è firmata da Apple: su un altro Mac, al primo avvio, Impostazioni di Sistema → Privacy e sicurezza → «Apri comunque».

## File
- `Sorgenti/main.swift` — avvio, menu, elenco delle scorciatoie (⌘K)
- `Sorgenti/Snippet.swift` — **le scorciatoie**, divise in sezioni: per aggiungerne una copia una riga e ricompila
- `Sorgenti/Legenda.swift` — la legenda (⌘K): ricerca, sezioni, schede con anteprima; clic = inserisci
- `Sorgenti/Editor.swift` — editor: colori del codice, numeri di riga, riga corrente, Tab/Invio/commenti
- `Sorgenti/Albero.swift` — albero dei file a sinistra: cartelle, operazioni, trascinamento, aggiornamento automatico
- `Sorgenti/Tema.swift` — i colori (JetBrains «Dark» della New UI e «IntelliJ Light»), segue l'aspetto del Mac
- `Sorgenti/Finestra.swift` — finestra, barra in alto, console, errori cliccabili
- `Sorgenti/Esecuzione.swift` — compila con clang ed esegue il programma in un terminale finto (pty)
- `Sorgenti/FinestraImpostazioni.swift` — Impostazioni (⌘,): aspetto, carattere, standard del C, avvisi, cartella
- `Sorgenti/Documento.swift` — apri/salva (salvataggio automatico, versioni, schede: li fa macOS)
- `pubblica.sh` (carica su GitHub), `crea-dmg.sh` (DMG e release), `sfondo-dmg.swift` e `dmg.py` (aspetto del DMG), `Info.plist`, `icona.swift` (disegna l'icona: grigio scuro e forma come il Terminale di macOS, C bianca), `compila.sh`

## Albero dei file
- Mostra la cartella del progetto (di base `~/Documents/Programmi C`, si cambia con ⇧⌘O). ⇧⌘S (o ⌘1) lo mostra o nasconde.
- Tasto destro: nuovo file C, nuova cartella, rinomina, duplica, copia percorso, mostra nel Finder,
  apri nel Terminale, sposta nel Cestino (anche ⌘⌫). Doppio clic o Invio apre.
- Trascinare sposta tra cartelle; trascinare dal Finder copia. I file aperti seguono gli spostamenti.
- Si aggiorna da solo se cambi i file da fuori (FSEvents).

## Dove finiscono le cose
- Programmi nuovi: si propongono in `~/Documents/Programmi C` (si può salvare ovunque).
- Eseguibili compilati: `~/Library/Caches/IDE C/` (cancellati quando chiudi la finestra).
- Compilazione: `clang -std=<scelto nelle Impostazioni> [-Wall] [-pedantic] … -lm` (di base C11 con -Wall).
