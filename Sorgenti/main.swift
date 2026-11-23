import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: Impostazioni.cartellaProgrammi, withIntermediateDirectories: true)
        Osservatore.shared.osserva(Progetto.radice)
    }

    @objc func mostraImpostazioni(_ sender: Any?) { FinestraImpostazioni.shared.mostra() }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    // MARK: Legenda delle scorciatoie (⌘K)

    @objc func mostraScorciatoie(_ sender: Any?) { Legenda.shared.alterna() }

    /// ⌘N: chiede il nome e crea il file nella cartella che hai scelto nell'albero.
    @objc func nuovoFileC(_ sender: Any?) {
        let finestra = (NSDocumentController.shared.currentDocument as? Documento)?.finestra
            ?? NSApp.orderedWindows.compactMap { $0.windowController as? FinestraController }.first
        if let f = finestra {
            f.window?.makeKeyAndOrderFront(nil)
            f.nuovoFileNelProgetto(nil)
        } else {
            NSDocumentController.shared.newDocument(nil)
        }
    }
}

// MARK: - Menu

private func voce(_ titolo: String, _ azione: Selector?, _ tasto: String = "",
                  _ modificatori: NSEvent.ModifierFlags = .command, tag: Int = 0, target: AnyObject? = nil) -> NSMenuItem {
    let v = NSMenuItem(title: titolo, action: azione, keyEquivalent: tasto)
    v.keyEquivalentModifierMask = modificatori
    v.tag = tag
    v.target = target
    return v
}

private func menu(_ titolo: String, _ voci: [NSMenuItem]) -> NSMenuItem {
    let m = NSMenu(title: titolo)
    voci.forEach { m.addItem($0) }
    let v = NSMenuItem(title: titolo, action: nil, keyEquivalent: "")
    v.submenu = m
    return v
}

private func costruisciMenu(_ delegato: AppDelegate) -> NSMenu {
    let principale = NSMenu()
    let sep = { NSMenuItem.separator() }

    principale.addItem(menu("IDE C", [
        voce("Informazioni su IDE C", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
        sep(),
        voce("Impostazioni…", #selector(AppDelegate.mostraImpostazioni(_:)), ",", target: delegato),
        sep(),
        voce("Nascondi IDE C", #selector(NSApplication.hide(_:)), "h"),
        voce("Nascondi altre", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
        voce("Mostra tutte", #selector(NSApplication.unhideAllApplications(_:))),
        sep(),
        voce("Esci da IDE C", #selector(NSApplication.terminate(_:)), "q"),
    ]))

    let recenti = menu("Apri recenti", [voce("Pulisci menu", #selector(NSDocumentController.clearRecentDocuments(_:)))])
    principale.addItem(menu("File", [
        voce("Nuovo file C…", #selector(AppDelegate.nuovoFileC(_:)), "n", target: delegato),
        voce("Nuovo documento senza nome", #selector(NSDocumentController.newDocument(_:)), "n", [.command, .option]),
        voce("Nuova cartella nel progetto…", #selector(FinestraController.nuovaCartellaNelProgetto(_:)), "n", [.command, .option, .shift]),
        voce("Apri…", #selector(NSDocumentController.openDocument(_:)), "o"),
        voce("Scegli la cartella del progetto…", #selector(FinestraController.scegliCartellaProgetto(_:)), "o", [.command, .shift]),
        recenti,
        sep(),
        voce("Chiudi", #selector(NSWindow.performClose(_:)), "w"),
        voce("Salva", #selector(NSDocument.save(_:)), "s"),
        voce("Duplica", #selector(NSDocument.duplicate(_:)), "S", [.command, .option]),
        voce("Rinomina…", #selector(NSDocument.rename(_:))),
        voce("Sposta in…", #selector(NSDocument.move(_:))),
        voce("Ripristina a", #selector(NSDocument.revertToSaved(_:))),
    ]))

    let trova = menu("Trova", [
        voce("Trova…", #selector(NSTextView.performTextFinderAction(_:)), "f", tag: NSTextFinder.Action.showFindInterface.rawValue),
        voce("Trova e sostituisci…", #selector(NSTextView.performTextFinderAction(_:)), "f", [.command, .option],
             tag: NSTextFinder.Action.showReplaceInterface.rawValue),
        voce("Trova successivo", #selector(NSTextView.performTextFinderAction(_:)), "g", tag: NSTextFinder.Action.nextMatch.rawValue),
        voce("Trova precedente", #selector(NSTextView.performTextFinderAction(_:)), "g", [.command, .shift],
             tag: NSTextFinder.Action.previousMatch.rawValue),
        voce("Usa selezione per trovare", #selector(NSTextView.performTextFinderAction(_:)), "e",
             tag: NSTextFinder.Action.setSearchString.rawValue),
    ])
    principale.addItem(menu("Modifica", [
        voce("Annulla", Selector(("undo:")), "z"),
        voce("Ripeti", Selector(("redo:")), "z", [.command, .shift]),
        sep(),
        voce("Taglia", #selector(NSText.cut(_:)), "x"),
        voce("Copia", #selector(NSText.copy(_:)), "c"),
        voce("Incolla", #selector(NSText.paste(_:)), "v"),
        voce("Seleziona tutto", #selector(NSText.selectAll(_:)), "a"),
        sep(),
        voce("Commenta righe", #selector(EditorC.commentaRighe(_:)), "/"),
        trova,
    ]))

    principale.addItem(menu("Programma", [
        voce("Compila", #selector(FinestraController.compila(_:)), "b"),
        voce("Esegui", #selector(FinestraController.esegui(_:)), "r"),
        voce("Ferma", #selector(FinestraController.ferma(_:)), "."),
        voce("Fine input (EOF)", #selector(FinestraController.fineInput(_:)), "d"),
        sep(),
        voce("Scorciatoie", #selector(AppDelegate.mostraScorciatoie(_:)), "k", target: delegato),
    ]))

    principale.addItem(menu("Vista", [
        voce("Nascondi i file", #selector(FinestraController.mostraNascondiFile(_:)), "S", [.command]),   // «S» maiuscola = ⇧⌘S
        {   // ⌘1 fa la stessa cosa (voce nascosta, funziona solo da tastiera)
            let v = voce("Nascondi i file", #selector(FinestraController.mostraNascondiFile(_:)), "1")
            v.isHidden = true
            v.allowsKeyEquivalentWhenHidden = true
            return v
        }(),
        sep(),
        voce("Testo più grande", #selector(FinestraController.ingrandisci(_:)), "+"),
        voce("Testo più piccolo", #selector(FinestraController.rimpicciolisci(_:)), "-"),
        voce("Dimensione normale", #selector(FinestraController.dimensioneNormale(_:)), "0"),
        sep(),
        voce("Mostra barra delle schede", #selector(NSWindow.toggleTabBar(_:)), ""),
        voce("Mostra tutte le schede", #selector(NSWindow.toggleTabOverview(_:)), "\\", [.command, .shift]),
        voce("Schermo intero", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
    ]))

    let finestre = menu("Finestra", [
        voce("Riduci a icona", #selector(NSWindow.performMiniaturize(_:)), "m"),
        voce("Zoom", #selector(NSWindow.performZoom(_:))),
        sep(),
        voce("Porta tutto in primo piano", #selector(NSApplication.arrangeInFront(_:))),
    ])
    principale.addItem(finestre)
    NSApp.windowsMenu = finestre.submenu

    let aiuto = menu("Aiuto", [
        voce("Scorciatoie", #selector(AppDelegate.mostraScorciatoie(_:)), "?", target: delegato),
    ])
    principale.addItem(aiuto)
    NSApp.helpMenu = aiuto.submenu
    return principale
}

// MARK: - Avvio

let app = NSApplication.shared
Impostazioni.aspetto.applica()
let delegato = AppDelegate()
app.delegate = delegato
_ = NSDocumentController.shared
app.setActivationPolicy(.regular)
app.mainMenu = costruisciMenu(delegato)
app.run()
