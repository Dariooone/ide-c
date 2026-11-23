import AppKit
import Symbols

extension NSToolbarItem.Identifier {
    static let alberoFile = Self("alberoFile")
    static let compila = Self("compila")
    static let esegui = Self("esegui")
    static let ferma = Self("ferma")
    static let scorciatoie = Self("scorciatoie")
}

/// Icona animata accanto allo stato della console.
enum IconaStato {
    case pronto, compila, esegue, ok, errore, avviso, fermo
    var simbolo: String {
        switch self {
        case .pronto: return "chevron.left.forwardslash.chevron.right"
        case .compila: return "hammer.fill"
        case .esegue: return "play.circle.fill"
        case .ok: return "checkmark.circle.fill"
        case .errore: return "xmark.octagon.fill"
        case .avviso: return "exclamationmark.triangle.fill"
        case .fermo: return "stop.circle.fill"
        }
    }
}

/// Vista piena di un colore del tema.
final class Sfondo: NSView {
    var colore: NSColor
    init(_ colore: NSColor) {
        self.colore = colore
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("non usato") }
    override func draw(_ dirtyRect: NSRect) {
        colore.setFill()
        bounds.intersection(dirtyRect).fill()   // da macOS 14 dirtyRect può uscire dai bordi
    }
}

final class FinestraController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSTextViewDelegate,
                                NSMenuItemValidation, NSToolbarItemValidation {
    let editor: EditorC
    private let colorazione = Colorazione()
    private let scrollEditor = NSScrollView()
    private let numeri: NumeriRiga
    private let console: NSTextView
    private let scrollConsole: NSScrollView
    private let ingresso = NSTextField()
    private let prompt = NSTextField(labelWithString: "›")
    private let stato = NSTextField(labelWithString: "")
    private let simbolo = NSImageView()
    private let pannelloFile = PannelloFile(frame: NSRect(x: 0, y: 0, width: 240, height: 600))
    /// Colonna dei file (sidebar standard di macOS, traslucida) + editor e console.
    private let colonne = NSSplitViewController()
    private var voceFile: NSSplitViewItem!
    private let destra = Divisore()
    private var fileVisibili: Bool { !(voceFile?.isCollapsed ?? false) }
    private var esecuzione: Esecuzione?
    private let cache: URL

    init(documento: Documento) {
        cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IDE C/\(UUID().uuidString)", isDirectory: true)

        // editor (TextKit 1, senza a capo automatico)
        let ts = NSTextStorage()
        let lm = NSLayoutManager()
        ts.addLayoutManager(lm)
        let tc = NSTextContainer(size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        tc.widthTracksTextView = false
        lm.addTextContainer(tc)
        editor = EditorC(frame: NSRect(x: 0, y: 0, width: 800, height: 500), textContainer: tc)
        numeri = NumeriRiga(scrollView: scrollEditor, editor: editor)

        scrollConsole = NSTextView.scrollableTextView()
        console = scrollConsole.documentView as! NSTextView

        let finestra = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                backing: .buffered, defer: false)
        super.init(window: finestra)

        ts.delegate = colorazione
        preparaEditor()
        preparaConsole()
        preparaFinestra(finestra)
        editor.string = documento.testo
        numeri.aggiorna()
        pannelloFile.finestra = finestra
        pannelloFile.fileAttivo = documento.fileURL

        NotificationCenter.default.addObserver(self, selector: #selector(applicaFont),
                                               name: .dimensioneTesto, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    deinit {
        esecuzione?.ferma()
        try? FileManager.default.removeItem(at: cache)
    }

    // MARK: - Costruzione

    private func preparaEditor() {
        let e = editor
        e.isRichText = false
        e.importsGraphics = false
        e.allowsUndo = true
        e.usesFindBar = true
        e.isIncrementalSearchingEnabled = true
        e.isAutomaticQuoteSubstitutionEnabled = false
        e.isAutomaticDashSubstitutionEnabled = false
        e.isAutomaticTextReplacementEnabled = false
        e.isAutomaticSpellingCorrectionEnabled = false
        e.isContinuousSpellCheckingEnabled = false
        e.isGrammarCheckingEnabled = false
        e.isAutomaticLinkDetectionEnabled = false
        e.isAutomaticDataDetectionEnabled = false
        e.isAutomaticTextCompletionEnabled = false
        e.smartInsertDeleteEnabled = false
        if #available(macOS 14.0, *) { e.inlinePredictionType = .no }
        if #available(macOS 15.0, *) { e.writingToolsBehavior = .none }
        e.textContainerInset = NSSize(width: 6, height: 10)
        e.isHorizontallyResizable = true
        e.isVerticallyResizable = true
        e.minSize = .zero
        e.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        e.autoresizingMask = [.width, .height]
        e.backgroundColor = Tema.editor
        e.insertionPointColor = Tema.cursore
        e.selectedTextAttributes = [.backgroundColor: Tema.selezione]
        e.delegate = self
        applicaFontEditor()

        scrollEditor.documentView = e
        scrollEditor.hasVerticalScroller = true
        scrollEditor.hasHorizontalScroller = true
        scrollEditor.autohidesScrollers = true
        scrollEditor.borderType = .noBorder
        scrollEditor.backgroundColor = Tema.editor
        scrollEditor.verticalRulerView = numeri
        scrollEditor.hasVerticalRuler = true
        scrollEditor.rulersVisible = true
        scrollEditor.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                               object: scrollEditor.contentView, queue: .main) { [weak self] _ in
            self?.numeri.needsDisplay = true
        }
    }

    private func preparaConsole() {
        console.isEditable = false
        console.isSelectable = true
        console.isRichText = true
        console.textContainerInset = NSSize(width: 10, height: 8)
        console.backgroundColor = Tema.editor
        console.selectedTextAttributes = [.backgroundColor: Tema.selezione]
        console.linkTextAttributes = [.cursor: NSCursor.pointingHand, .underlineStyle: NSUnderlineStyle.single.rawValue]
        console.delegate = self
        scrollConsole.borderType = .noBorder
        scrollConsole.backgroundColor = Tema.editor

        ingresso.isBordered = false
        ingresso.isBezeled = false
        ingresso.drawsBackground = false
        ingresso.focusRingType = .none
        ingresso.textColor = Tema.input
        ingresso.target = self
        ingresso.action = #selector(inviaIngresso(_:))
        ingresso.lineBreakMode = .byTruncatingTail
        prompt.textColor = Tema.input
        stato.textColor = Tema.tenue
        stato.lineBreakMode = .byTruncatingTail
        stato.wantsLayer = true
        simbolo.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        simbolo.image = NSImage(systemSymbolName: IconaStato.pronto.simbolo, accessibilityDescription: nil)
        simbolo.isHidden = true          // compare solo quando compili o esegui
        simbolo.contentTintColor = Tema.tenue
        applicaFontConsole()
    }

    private func preparaFinestra(_ finestra: NSWindow) {
        // pannello in basso: stato, console, riga dell'input
        let pannello = Sfondo(Tema.pannello)
        let rigaIngresso = Sfondo(Tema.editor)
        let linea1 = Linea(), linea2 = Linea()
        for v in [prompt, ingresso] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            rigaIngresso.addSubview(v)
        }
        let iconaConsole = NSImageView(image: NSImage(systemSymbolName: "terminal", accessibilityDescription: "Console")!)
        iconaConsole.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        iconaConsole.contentTintColor = Tema.tenue
        let titoloConsole = NSTextField(labelWithString: "Console")
        titoloConsole.font = .systemFont(ofSize: 12, weight: .semibold)
        titoloConsole.textColor = Tema.testoPannello
        titoloConsole.setContentHuggingPriority(.required, for: .horizontal)
        titoloConsole.setContentCompressionResistancePriority(.required, for: .horizontal)
        let divisorio = Linea()
        for v in [iconaConsole, titoloConsole, divisorio, stato] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            pannello.addSubview(v)
        }
        NSLayoutConstraint.activate([
            iconaConsole.leadingAnchor.constraint(equalTo: pannello.leadingAnchor, constant: 12),
            iconaConsole.centerYAnchor.constraint(equalTo: stato.centerYAnchor),
            iconaConsole.widthAnchor.constraint(equalToConstant: 16),
            iconaConsole.heightAnchor.constraint(equalToConstant: 16),
            titoloConsole.leadingAnchor.constraint(equalTo: iconaConsole.trailingAnchor, constant: 6),
            titoloConsole.centerYAnchor.constraint(equalTo: stato.centerYAnchor),
            divisorio.leadingAnchor.constraint(equalTo: titoloConsole.trailingAnchor, constant: 12),
            divisorio.centerYAnchor.constraint(equalTo: stato.centerYAnchor),
            divisorio.widthAnchor.constraint(equalToConstant: 1),
            divisorio.heightAnchor.constraint(equalToConstant: 14),
        ])
        for v in [simbolo, linea1, scrollConsole, linea2, rigaIngresso] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            pannello.addSubview(v)
        }
        prompt.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            stato.topAnchor.constraint(equalTo: pannello.topAnchor, constant: 7),
            simbolo.leadingAnchor.constraint(equalTo: divisorio.trailingAnchor, constant: 12),
            simbolo.centerYAnchor.constraint(equalTo: stato.centerYAnchor),
            simbolo.widthAnchor.constraint(equalToConstant: 16),
            simbolo.heightAnchor.constraint(equalToConstant: 16),
            stato.leadingAnchor.constraint(equalTo: simbolo.trailingAnchor, constant: 7),
            stato.trailingAnchor.constraint(equalTo: pannello.trailingAnchor, constant: -12),
            linea1.topAnchor.constraint(equalTo: stato.bottomAnchor, constant: 7),
            linea1.leadingAnchor.constraint(equalTo: pannello.leadingAnchor),
            linea1.trailingAnchor.constraint(equalTo: pannello.trailingAnchor),
            linea1.heightAnchor.constraint(equalToConstant: 1),
            scrollConsole.topAnchor.constraint(equalTo: linea1.bottomAnchor),
            scrollConsole.leadingAnchor.constraint(equalTo: pannello.leadingAnchor),
            scrollConsole.trailingAnchor.constraint(equalTo: pannello.trailingAnchor),
            scrollConsole.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            linea2.topAnchor.constraint(equalTo: scrollConsole.bottomAnchor),
            linea2.leadingAnchor.constraint(equalTo: pannello.leadingAnchor),
            linea2.trailingAnchor.constraint(equalTo: pannello.trailingAnchor),
            linea2.heightAnchor.constraint(equalToConstant: 1),
            rigaIngresso.topAnchor.constraint(equalTo: linea2.bottomAnchor),
            rigaIngresso.leadingAnchor.constraint(equalTo: pannello.leadingAnchor),
            rigaIngresso.trailingAnchor.constraint(equalTo: pannello.trailingAnchor),
            rigaIngresso.bottomAnchor.constraint(equalTo: pannello.bottomAnchor),
            rigaIngresso.heightAnchor.constraint(equalToConstant: 30),
            prompt.leadingAnchor.constraint(equalTo: rigaIngresso.leadingAnchor, constant: 12),
            prompt.centerYAnchor.constraint(equalTo: rigaIngresso.centerYAnchor),
            ingresso.leadingAnchor.constraint(equalTo: prompt.trailingAnchor, constant: 6),
            ingresso.trailingAnchor.constraint(equalTo: rigaIngresso.trailingAnchor, constant: -12),
            ingresso.centerYAnchor.constraint(equalTo: rigaIngresso.centerYAnchor),
            pannello.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            scrollEditor.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            scrollEditor.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
        ])
        for v in [scrollEditor, pannello, destra] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        destra.isVertical = false
        destra.dividerStyle = .thin
        destra.addArrangedSubview(scrollEditor)
        destra.addArrangedSubview(pannello)
        destra.setHoldingPriority(.init(240), forSubviewAt: 0)
        destra.setHoldingPriority(.init(260), forSubviewAt: 1)

        // a destra: editor e console, sotto la barra in alto (la colonna dei file invece arriva fino in cima)
        let lato = Sfondo(Tema.pannello)
        lato.addSubview(destra)
        NSLayoutConstraint.activate([
            destra.topAnchor.constraint(equalTo: lato.safeAreaLayoutGuide.topAnchor),
            destra.leadingAnchor.constraint(equalTo: lato.leadingAnchor),
            destra.trailingAnchor.constraint(equalTo: lato.trailingAnchor),
            destra.bottomAnchor.constraint(equalTo: lato.bottomAnchor),
            lato.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])
        let vcContenuto = NSViewController()
        vcContenuto.view = lato
        let vcFile = NSViewController()
        vcFile.view = pannelloFile

        // la colonna dei file è una «sidebar» vera: traslucida (si vede lo sfondo dietro), alta fino in cima,
        // si apre e chiude con l'animazione di sistema
        voceFile = NSSplitViewItem(sidebarWithViewController: vcFile)
        voceFile.minimumThickness = 170
        voceFile.maximumThickness = 420
        voceFile.canCollapse = true
        voceFile.isCollapsed = UserDefaults.standard.bool(forKey: "alberoNascosto")
        let voceContenuto = NSSplitViewItem(viewController: vcContenuto)
        voceContenuto.minimumThickness = 360
        colonne.addSplitViewItem(voceFile)
        colonne.addSplitViewItem(voceContenuto)

        finestra.contentViewController = colonne
        finestra.setContentSize(NSSize(width: 1180, height: 760))
        finestra.delegate = self
        finestra.minSize = NSSize(width: 640, height: 420)
        finestra.tabbingMode = .preferred
        finestra.tabbingIdentifier = "IDEC"
        finestra.initialFirstResponder = editor
        finestra.center()

        let barra = NSToolbar(identifier: "IDEC.barra")
        barra.delegate = self
        barra.displayMode = .iconOnly
        finestra.toolbar = barra
        finestra.toolbarStyle = .unified

        posizionaDivisori()
        DispatchQueue.main.async { [weak self] in self?.posizionaDivisori() }
    }

    private func posizionaDivisori() {
        colonne.splitView.layoutSubtreeIfNeeded()
        if fileVisibili, pannelloFile.frame.width < 200 { colonne.splitView.setPosition(250, ofDividerAt: 0) }
        destra.layoutSubtreeIfNeeded()
        let altezza = destra.bounds.height > 300 ? destra.bounds.height : (window?.contentLayoutRect.height ?? 700)
        destra.setPosition(altezza - 250, ofDividerAt: 0)
    }

    // MARK: - Caratteri

    private func applicaFontEditor() {
        let f = Impostazioni.font
        colorazione.font = f
        editor.font = f
        editor.typingAttributes = [.font: f, .foregroundColor: Tema.testo,
                                   .paragraphStyle: Impostazioni.paragrafo(f)]
        editor.defaultParagraphStyle = Impostazioni.paragrafo(f)
        if let ts = editor.textStorage { colorazione.colora(ts) }
    }

    private var fontConsole: NSFont { Tema.mono(max(9, Impostazioni.dimensione - 1)) }

    private func applicaFontConsole() {
        console.font = fontConsole
        ingresso.font = fontConsole
        prompt.font = Tema.mono(max(9, Impostazioni.dimensione - 1), peso: .semibold)
        ingresso.placeholderAttributedString = NSAttributedString(
            string: "Input del programma: scrivi qui e premi Invio",
            attributes: [.font: fontConsole, .foregroundColor: Tema.numeriRiga])
        stato.font = .systemFont(ofSize: 12, weight: .medium)
    }

    @objc private func applicaFont() {
        applicaFontEditor()
        applicaFontConsole()
        numeri.aggiorna()
    }

    @objc func ingrandisci(_ sender: Any?) { Impostazioni.dimensione += 1 }
    @objc func rimpicciolisci(_ sender: Any?) { Impostazioni.dimensione -= 1 }
    @objc func dimensioneNormale(_ sender: Any?) { Impostazioni.dimensione = Impostazioni.dimensioneNormale }

    // MARK: - Albero dei file

    /// Apre o chiude la colonna dei file con l'animazione di sistema (⇧⌘S o ⌘1).
    @objc func mostraNascondiFile(_ sender: Any?) {
        let chiudi = fileVisibili
        UserDefaults.standard.set(chiudi, forKey: "alberoNascosto")
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.25
            c.allowsImplicitAnimation = true
            voceFile.animator().isCollapsed = chiudi
        }
    }

    @objc func nuovoFileNelProgetto(_ sender: Any?) {
        if !fileVisibili { mostraNascondiFile(nil) }
        pannelloFile.nuovoFile(nil)
    }

    @objc func nuovaCartellaNelProgetto(_ sender: Any?) {
        if !fileVisibili { mostraNascondiFile(nil) }
        pannelloFile.nuovaCartella(nil)
    }

    @objc func scegliCartellaProgetto(_ sender: Any?) { pannelloFile.scegliRadice(nil) }

    private let puntinoScheda = Puntino()

    /// Puntino sulla scheda della finestra quando il file ha modifiche non salvate.
    func aggiornaPuntino() {
        guard let w = window, let doc = document as? Documento else { return }
        if doc.isDocumentEdited {
            if w.tab.accessoryView !== puntinoScheda {
                puntinoScheda.toolTip = "Modifiche non ancora salvate"
                puntinoScheda.isHidden = true
                w.tab.accessoryView = puntinoScheda
            }
            puntinoScheda.mostra(true)
            w.tab.toolTip = "\(doc.displayName ?? "") — modifiche non salvate"
        } else {
            puntinoScheda.mostra(false)
            w.tab.toolTip = doc.displayName
        }
    }

    func aggiornaFileAttivo() {
        pannelloFile.fileAttivo = (document as? Documento)?.fileURL
    }

    func windowDidBecomeKey(_ notification: Notification) { aggiornaFileAttivo() }

    // MARK: - Documento

    func ricarica() {
        guard let doc = document as? Documento else { return }
        editor.fineSessione()
        editor.string = doc.testo
        numeri.aggiorna()
    }

    func textDidChange(_ notification: Notification) {
        if (notification.object as? NSTextView) === editor { numeri.aggiorna() }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        if (notification.object as? NSTextView) === editor { numeri.needsDisplay = true }
    }

    func windowWillClose(_ notification: Notification) {
        esecuzione?.ferma()
    }

    // MARK: - Barra in alto

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.alberoFile, .sidebarTrackingSeparator, .flexibleSpace, .compila, .esegui, .ferma, .space, .scorciatoie]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        let dati: (String, String, String, Selector, AnyObject?)
        switch id {
        case .alberoFile: dati = ("File", "sidebar.left", "Mostra o nascondi i file (⇧⌘S)", #selector(mostraNascondiFile(_:)), self)
        case .compila: dati = ("Compila", "hammer", "Compila e mostra gli errori (⌘B)", #selector(compila(_:)), self)
        case .esegui: dati = ("Esegui", "play.fill", "Compila ed esegui (⌘R)", #selector(esegui(_:)), self)
        case .ferma: dati = ("Ferma", "stop.fill", "Ferma il programma (⌘.)", #selector(ferma(_:)), self)
        case .scorciatoie:
            dati = ("Scorciatoie", "keyboard", "Elenco delle scorciatoie (⌘K)",
                    #selector(AppDelegate.mostraScorciatoie(_:)), NSApp.delegate as AnyObject?)
        default: return nil
        }
        item.label = dati.0
        item.paletteLabel = dati.0
        item.image = NSImage(systemSymbolName: dati.1, accessibilityDescription: dati.0)
        item.toolTip = dati.2
        item.action = dati.3
        item.target = dati.4
        item.isBordered = true
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool { valida(item.action) }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(mostraNascondiFile(_:)) {
            item.title = fileVisibili ? "Nascondi i file" : "Mostra i file"
        }
        return valida(item.action)
    }

    private func valida(_ azione: Selector?) -> Bool {
        switch azione {
        case #selector(ferma(_:)), #selector(fineInput(_:)): return esecuzione != nil
        default: return true
        }
    }

    // MARK: - Compila ed esegui

    @objc func compila(_ sender: Any?) { avvia(eseguire: false) }
    @objc func esegui(_ sender: Any?) { avvia(eseguire: true) }
    @objc func ferma(_ sender: Any?) { esecuzione?.ferma() }
    @objc func fineInput(_ sender: Any?) { esecuzione?.fineInput() }

    private func avvia(eseguire: Bool) {
        guard let doc = document as? Documento else { return }
        let nome = doc.fileURL?.lastPathComponent ?? "programma.c"
        guard nome.lowercased().hasSuffix(".c") else {
            impostaStato("Si compila solo un file .c: apri il file .c e compila quello.", colore: Tema.avviso, icona: .avviso)
            NSSound.beep()
            return
        }
        if doc.fileURL != nil, doc.isDocumentEdited { doc.save(nil) }
        esecuzione?.ferma()
        esecuzione = nil
        window?.toolbar?.validateVisibleItems()

        let cartella = doc.fileURL?.deletingLastPathComponent() ?? Impostazioni.cartellaProgrammi
        let testo = editor.string
        let cache = self.cache
        console.textStorage?.setAttributedString(NSAttributedString())
        impostaStato("Compilo \(nome)…", colore: Tema.tenue, icona: .compila)

        DispatchQueue.global(qos: .userInitiated).async {
            let r = Compilatore.compila(testo: testo, nome: nome, cache: cache, include: cartella)
            DispatchQueue.main.async { [weak self] in
                self?.finitaCompilazione(r, nome: nome, cartella: cartella, eseguire: eseguire)
            }
        }
    }

    private static let rigaClang = try! NSRegularExpression(
        pattern: #"^[^:\n]+:(\d+):(\d+): (fatal error|error|warning|note):"#)

    private func finitaCompilazione(_ r: RisultatoCompilazione, nome: String, cartella: URL, eseguire: Bool) {
        var errori = 0, avvisi = 0
        var segni: [Int: Bool] = [:]
        for riga in r.uscita.components(separatedBy: "\n") where !riga.isEmpty {
            let ns = riga as NSString
            var attr: [NSAttributedString.Key: Any] = [.font: fontConsole, .foregroundColor: Tema.tenue]
            if let m = FinestraController.rigaClang.firstMatch(in: riga, range: NSRange(location: 0, length: ns.length)),
               let n = Int(ns.substring(with: m.range(at: 1))) {
                switch ns.substring(with: m.range(at: 3)) {
                case "warning":
                    avvisi += 1
                    if segni[n] == nil { segni[n] = false }
                    attr[.foregroundColor] = Tema.avviso
                case "note":
                    attr[.foregroundColor] = Tema.tenue
                default:
                    errori += 1
                    segni[n] = true
                    attr[.foregroundColor] = Tema.errore
                }
                attr[.link] = "riga:\(n):\(ns.substring(with: m.range(at: 2)))"
            } else if riga.hasPrefix(" ") {
                attr[.foregroundColor] = Tema.testo
            }
            scriviConsole(riga + "\n", attr)
        }
        numeri.segni = segni

        if !r.ok {
            let parti = [errori > 0 ? "\(errori) \(errori == 1 ? "errore" : "errori")" : "errori",
                         avvisi > 0 ? "\(avvisi) \(avvisi == 1 ? "avviso" : "avvisi")" : nil].compactMap { $0 }
            impostaStato("Non compila: " + parti.joined(separator: ", ") + ". Clicca un errore per andare alla riga.",
                         colore: Tema.errore, icona: .errore)
            return
        }
        let avvisiTesto = avvisi > 0 ? " (\(avvisi) \(avvisi == 1 ? "avviso" : "avvisi"))" : ""
        guard eseguire else {
            impostaStato("Compilato" + avvisiTesto, colore: avvisi > 0 ? Tema.avviso : Tema.bene,
                         icona: avvisi > 0 ? .avviso : .ok)
            return
        }
        lancia(r.eseguibile, nome: nome, cartella: cartella, avvisi: avvisiTesto)
    }

    private func lancia(_ eseguibile: URL, nome: String, cartella: URL, avvisi: String) {
        if console.textStorage?.length ?? 0 > 0 { scriviConsole("\n", [:]) }
        scriviConsole("▶︎ \(nome)\n", [.foregroundColor: Tema.tenue])
        let e = Esecuzione()
        e.suUscita = { [weak self] t in self?.scriviConsole(t, [.foregroundColor: Tema.testo]) }
        e.suFine = { [weak self, weak e] motivo, codice, fermato in
            guard let self = self else { return }
            let messaggio: String
            var colore = Tema.tenue
            var coloreStato = Tema.bene
            if fermato {
                messaggio = "Processo fermato"
                coloreStato = Tema.tenue
            } else if motivo == .uncaughtSignal {
                colore = Tema.errore
                coloreStato = Tema.errore
                switch codice {
                case SIGSEGV, SIGBUS: messaggio = "Il programma si è bloccato: accesso a memoria non valida (segmentation fault)"
                case SIGFPE: messaggio = "Il programma si è bloccato: errore di calcolo (divisione per zero?)"
                case SIGABRT: messaggio = "Il programma si è interrotto (abort)"
                default: messaggio = "Il programma si è bloccato (segnale \(codice))"
                }
            } else {
                messaggio = "Processo terminato con codice di uscita \(codice)"
                if codice != 0 { coloreStato = Tema.avviso }
            }
            self.scriviConsole("\n" + messaggio + "\n", [.foregroundColor: colore])
            let icona: IconaStato = fermato ? .fermo : (motivo == .uncaughtSignal ? .errore : (codice != 0 ? .avviso : .ok))
            self.impostaStato(messaggio, colore: coloreStato, icona: icona)
            if self.esecuzione === e { self.esecuzione = nil }
            self.window?.toolbar?.validateVisibleItems()
        }
        do {
            try e.avvia(eseguibile, cartella: cartella)
            esecuzione = e
            impostaStato("In esecuzione" + avvisi + "… scrivi l'input qui sotto. ⌘. per fermare.", colore: Tema.infoBlu, icona: .esegue)
            window?.toolbar?.validateVisibleItems()
            window?.makeFirstResponder(ingresso)
        } catch {
            impostaStato(error.localizedDescription, colore: Tema.errore, icona: .errore)
        }
    }

    @objc private func inviaIngresso(_ sender: NSTextField) {
        guard let e = esecuzione else {
            if !sender.stringValue.isEmpty { NSSound.beep() }
            return
        }
        scriviConsole(sender.stringValue + "\n", [.foregroundColor: Tema.input])
        e.scrivi(sender.stringValue + "\n")
        sender.stringValue = ""
    }

    // MARK: - Console

    private func scriviConsole(_ testo: String, _ attr: [NSAttributedString.Key: Any]) {
        guard let ts = console.textStorage else { return }
        var a = attr
        if a[.font] == nil { a[.font] = fontConsole }
        if a[.foregroundColor] == nil { a[.foregroundColor] = Tema.testo }
        ts.append(NSAttributedString(string: testo, attributes: a))
        let massimo = 300_000
        if ts.length > massimo { ts.deleteCharacters(in: NSRange(location: 0, length: ts.length - massimo)) }
        console.scrollToEndOfDocument(nil)
    }

    private func impostaStato(_ testo: String, colore: NSColor, icona: IconaStato) {
        // il testo cambia con una breve dissolvenza
        let dissolvenza = CATransition()
        dissolvenza.type = .fade
        dissolvenza.duration = 0.2
        stato.layer?.add(dissolvenza, forKey: "testo")
        stato.stringValue = testo
        stato.textColor = colore
        simbolo.isHidden = false

        // l'icona si trasforma; pulsa mentre lavora, rimbalza quando ha finito
        guard let immagine = NSImage(systemSymbolName: icona.simbolo, accessibilityDescription: nil) else { return }
        simbolo.contentTintColor = colore
        if #available(macOS 14.0, *) {
            simbolo.removeAllSymbolEffects()
            simbolo.setSymbolImage(immagine, contentTransition: .replace)
            switch icona {
            case .compila, .esegue: simbolo.addSymbolEffect(.pulse, options: .repeating)
            case .ok, .errore, .avviso: simbolo.addSymbolEffect(.bounce, options: .nonRepeating)
            default: break
            }
        } else {
            simbolo.image = immagine
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard textView === console, let s = link as? String, s.hasPrefix("riga:") else { return false }
        let parti = s.split(separator: ":")
        guard parti.count >= 2, let n = Int(parti[1]) else { return false }
        vaiAllaRiga(n, colonna: parti.count > 2 ? Int(parti[2]) ?? 1 : 1)
        return true
    }

    private func vaiAllaRiga(_ n: Int, colonna: Int) {
        let ns = editor.string as NSString
        var riga = 1, i = 0
        while riga < n, i < ns.length {
            i = NSMaxRange(ns.lineRange(for: NSRange(location: i, length: 0)))
            riga += 1
        }
        let lr = ns.lineRange(for: NSRange(location: min(i, ns.length), length: 0))
        let cursore = min(lr.location + max(0, colonna - 1), NSMaxRange(lr))
        window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: cursore, length: 0))
        editor.scrollRangeToVisible(lr)
        if lr.length > 0 { editor.showFindIndicator(for: lr) }
    }
}
