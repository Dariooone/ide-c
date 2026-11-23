# IDE C

App nativa per macOS (Swift + AppKit) per scrivere, compilare ed eseguire programmi in C.
Niente completamento automatico né suggerimenti: solo **scorciatoie** (scrivi `main` e premi Tab).

## Costruire l'app
Serve solo `xcode-select --install` (clang e swiftc, niente Xcode).

```
./compila.sh
```

Crea `~/Applications/IDE C.app` (fuori dal vault). Dopo ogni modifica ai sorgenti si rilancia lo stesso comando.

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
- `Info.plist`, `icona.swift` (disegna l'icona: grigio scuro e forma come il Terminale di macOS, C bianca), `compila.sh`

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
