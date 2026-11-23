import AppKit

/// Tasti dell'app mostrati in fondo alla legenda.
let TASTI: [([String], String)] = [
    (["⌘", "B"], "Compila e mostra gli errori"),
    (["⌘", "R"], "Compila ed esegui nella console"),
    (["⌘", "."], "Ferma il programma"),
    (["⌘", "D"], "Fine input (EOF, come Ctrl+D)"),
    (["⌘", "/"], "Commenta o scommenta le righe"),
    (["Tab"], "Inserisce la scorciatoia o passa al punto successivo"),
    (["⇧", "Tab"], "Toglie il rientro (anche su più righe)"),
    (["Esc"], "Smette di saltare tra i punti da riempire"),
    (["⇧", "⌘", "S"], "Mostra o nasconde la colonna dei file (anche ⌘1)"),
    (["⌘", "N"], "Nuovo file C nella cartella cliccata nell'albero"),
    (["⇧", "⌘", "O"], "Scegli la cartella del progetto"),
    (["⌘", "F"], "Trova (⌥⌘F trova e sostituisci)"),
    (["⌘", "+"], "Testo più grande (⌘− più piccolo)"),
    (["⌘", "K"], "Apre o chiude questa legenda"),
    (["⌘", ","], "Impostazioni: aspetto, carattere, standard del C"),
]

/// Vista con l'origine in alto, per far scorrere la legenda dall'alto in basso.
final class Capovolta: NSView {
    override var isFlipped: Bool { true }
}

/// Etichetta arrotondata (la parola della scorciatoia o un tasto).
final class Pillola: NSView {
    private let testo: NSTextField
    private let sfondo: NSColor

    init(_ s: String, colore: NSColor, sfondo: NSColor, font: NSFont) {
        testo = NSTextField(labelWithString: s)
        self.sfondo = sfondo
        super.init(frame: .zero)
        testo.font = font
        testo.textColor = colore
        testo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(testo)
        NSLayoutConstraint.activate([
            testo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            testo.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            testo.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            testo.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    override func draw(_ dirtyRect: NSRect) {
        sfondo.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }
}

/// Una scorciatoia: parola, descrizione e anteprima colorata del codice. Clic = inserisci.
final class SchedaSnippet: NSView {
    private let azione: () -> Void
    private var sopra = false
    private let suggerimento = NSTextField(labelWithString: "Inserisci ↩︎")

    init(_ s: Snippet, anteprima: NSAttributedString, azione: @escaping () -> Void) {
        self.azione = azione
        super.init(frame: .zero)

        let parola = Pillola(s.parola, colore: Tema.parolaChiave, sfondo: Tema.parolaChiave.withAlphaComponent(0.14),
                             font: Tema.mono(12.5, peso: .semibold))
        let descrizione = NSTextField(labelWithString: s.descrizione)
        descrizione.font = .systemFont(ofSize: 13, weight: .medium)
        descrizione.textColor = Tema.testoPannello
        descrizione.lineBreakMode = .byTruncatingTail
        descrizione.setContentCompressionResistancePriority(.init(200), for: .horizontal)
        suggerimento.font = .systemFont(ofSize: 11, weight: .medium)
        suggerimento.textColor = Tema.infoBlu
        suggerimento.alphaValue = 0
        suggerimento.isHidden = true
        let codice = NSTextField(labelWithAttributedString: anteprima)
        codice.maximumNumberOfLines = 0
        codice.lineBreakMode = .byClipping
        codice.setContentCompressionResistancePriority(.init(200), for: .horizontal)

        for v in [parola, descrizione, suggerimento, codice] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            parola.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            parola.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            descrizione.centerYAnchor.constraint(equalTo: parola.centerYAnchor),
            descrizione.leadingAnchor.constraint(equalTo: parola.trailingAnchor, constant: 10),
            suggerimento.centerYAnchor.constraint(equalTo: parola.centerYAnchor),
            suggerimento.leadingAnchor.constraint(greaterThanOrEqualTo: descrizione.trailingAnchor, constant: 8),
            suggerimento.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            codice.topAnchor.constraint(equalTo: parola.bottomAnchor, constant: 8),
            codice.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            codice.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            codice.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11),
        ])
        toolTip = "Scrivi «\(s.parola)» e premi Tab, oppure clicca per inserirla"
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    private var premuta = false

    override func draw(_ dirtyRect: NSRect) {
        let forma = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        (premuta ? Tema.selezioneAlbero : sopra ? Tema.schedaSopra : Tema.scheda).setFill()
        forma.fill()
        (sopra ? Tema.lampo.withAlphaComponent(0.55) : Tema.bordoScheda).setStroke()
        forma.lineWidth = 1
        forma.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    private func evidenzia(_ si: Bool) {
        sopra = si
        premuta = false
        needsDisplay = true
        if si { suggerimento.isHidden = false }
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.18
            suggerimento.animator().alphaValue = si ? 1 : 0
        }, completionHandler: { [weak self] in
            if let self = self, !self.sopra { self.suggerimento.isHidden = true }
        })
    }

    override func mouseEntered(with event: NSEvent) { evidenzia(true) }
    override func mouseExited(with event: NSEvent) { evidenzia(false) }

    override func mouseDown(with event: NSEvent) {
        premuta = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let dentro = bounds.contains(convert(event.locationInWindow, from: nil))
        evidenzia(dentro)
        if dentro { azione() }
    }
}

/// La legenda delle scorciatoie (⌘K): ricerca, sezioni, schede.
final class Legenda: NSWindowController, NSSearchFieldDelegate, NSWindowDelegate {
    static let shared = Legenda()

    private let ricerca = NSSearchField()
    private let pila = NSStackView()
    private let scroll = NSScrollView()
    private let colorazione = Colorazione()
    private var anteprime: [String: NSAttributedString] = [:]

    private init() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
                        backing: .buffered, defer: false)
        super.init(window: p)
        p.title = "Scorciatoie"
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true
        p.becomesKeyOnlyIfNeeded = false
        p.backgroundColor = Tema.pannello
        p.minSize = NSSize(width: 460, height: 360)
        p.animationBehavior = .utilityWindow
        p.delegate = self
        p.setFrameAutosaveName("IDEC.legenda")
        if p.frame.origin == .zero { p.center() }
        costruisci(p)
        popola("")
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    func alterna() {
        guard let w = window else { return }
        if w.isVisible, w.isKeyWindow { w.orderOut(nil); return }
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(ricerca)
        animaComparsa()
    }

    private func costruisci(_ p: NSPanel) {
        let contenuto = Sfondo(Tema.pannello)
        p.contentView = contenuto

        let titolo = NSTextField(labelWithString: "Scorciatoie")
        titolo.font = .systemFont(ofSize: 22, weight: .bold)
        titolo.textColor = Tema.testoPannello
        let sottotitolo = NSTextField(labelWithString: "Scrivi la parola nell'editor e premi Tab, oppure clicca una scheda per inserirla.")
        sottotitolo.font = .systemFont(ofSize: 12.5)
        sottotitolo.textColor = Tema.tenue
        sottotitolo.lineBreakMode = .byWordWrapping
        sottotitolo.maximumNumberOfLines = 2
        ricerca.placeholderString = "Cerca: printf, scanf, matrice, file…"
        ricerca.delegate = self
        ricerca.sendsSearchStringImmediately = true
        ricerca.controlSize = .large

        let documento = Capovolta()
        pila.orientation = .vertical
        pila.alignment = .leading
        pila.spacing = 8
        pila.edgeInsets = NSEdgeInsets(top: 4, left: 18, bottom: 24, right: 18)
        pila.translatesAutoresizingMaskIntoConstraints = false
        documento.addSubview(pila)
        documento.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = documento
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        for v in [titolo, sottotitolo, ricerca, scroll] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contenuto.addSubview(v)
        }
        NSLayoutConstraint.activate([
            titolo.topAnchor.constraint(equalTo: contenuto.topAnchor, constant: 38),
            titolo.leadingAnchor.constraint(equalTo: contenuto.leadingAnchor, constant: 20),
            sottotitolo.topAnchor.constraint(equalTo: titolo.bottomAnchor, constant: 4),
            sottotitolo.leadingAnchor.constraint(equalTo: titolo.leadingAnchor),
            sottotitolo.trailingAnchor.constraint(equalTo: contenuto.trailingAnchor, constant: -20),
            ricerca.topAnchor.constraint(equalTo: sottotitolo.bottomAnchor, constant: 14),
            ricerca.leadingAnchor.constraint(equalTo: contenuto.leadingAnchor, constant: 18),
            ricerca.trailingAnchor.constraint(equalTo: contenuto.trailingAnchor, constant: -18),
            scroll.topAnchor.constraint(equalTo: ricerca.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: contenuto.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contenuto.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contenuto.bottomAnchor),
            documento.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            documento.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            documento.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            pila.leadingAnchor.constraint(equalTo: documento.leadingAnchor),
            pila.trailingAnchor.constraint(equalTo: documento.trailingAnchor),
            pila.topAnchor.constraint(equalTo: documento.topAnchor),
            pila.bottomAnchor.constraint(equalTo: documento.bottomAnchor),
        ])
    }

    // MARK: Contenuto

    private func anteprima(_ s: Snippet) -> NSAttributedString {
        if let a = anteprime[s.parola] { return a }
        colorazione.font = Tema.mono(11.5)
        let e = espandi(s.testo, rientro: "")
        let ts = NSTextStorage(string: e.testo)
        colorazione.colora(ts)
        // i punti da riempire hanno uno sfondo azzurro, il cursore finale è una barretta blu
        for r in e.punti.dropLast() where r.length > 0 {
            ts.addAttribute(.backgroundColor, value: Tema.lampo.withAlphaComponent(0.22), range: r)
        }
        if let fine = e.punti.last {
            ts.insert(NSAttributedString(string: "▏", attributes: [.font: Tema.mono(11.5, peso: .semibold),
                                                                   .foregroundColor: Tema.lampo]), at: fine.location)
        }
        let a = NSAttributedString(attributedString: ts)
        anteprime[s.parola] = a
        return a
    }

    private func titoloSezione(_ nome: String, simbolo: String, quante: Int) -> NSView {
        let icona = NSImageView(image: NSImage(systemSymbolName: simbolo, accessibilityDescription: nil) ?? NSImage())
        icona.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        icona.contentTintColor = Tema.infoBlu
        let testo = NSTextField(labelWithString: nome)
        testo.font = .systemFont(ofSize: 14, weight: .semibold)
        testo.textColor = Tema.testoPannello
        let numero = NSTextField(labelWithString: quante > 0 ? "\(quante)" : "")
        numero.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        numero.textColor = Tema.tenue
        let riga = NSStackView(views: [icona, testo, numero])
        riga.spacing = 7
        return riga
    }

    private func larga(_ v: NSView) {
        pila.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: pila.widthAnchor, constant: -36).isActive = true
    }

    private func popola(_ filtro: String) {
        pila.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let f = filtro.trimmingCharacters(in: .whitespaces).lowercased()
        func corrisponde(_ testi: [String]) -> Bool {
            f.isEmpty || testi.contains { $0.lowercased().contains(f) }
        }
        var trovate = 0
        for sezione in SEZIONI {
            let lista = sezione.snippet.filter { corrisponde([$0.parola, $0.descrizione, $0.testo, sezione.nome]) }
            guard !lista.isEmpty else { continue }
            if let ultimo = pila.arrangedSubviews.last { pila.setCustomSpacing(22, after: ultimo) }
            let titolo = titoloSezione(sezione.nome, simbolo: sezione.simbolo, quante: lista.count)
            pila.addArrangedSubview(titolo)
            pila.setCustomSpacing(10, after: titolo)
            for s in lista {
                larga(SchedaSnippet(s, anteprima: anteprima(s)) { [weak self] in self?.inserisci(s) })
                trovate += 1
            }
        }
        let tasti = TASTI.filter { corrisponde([$0.1] + $0.0) }
        if !tasti.isEmpty {
            if let ultimo = pila.arrangedSubviews.last { pila.setCustomSpacing(22, after: ultimo) }
            let titolo = titoloSezione("Tasti", simbolo: "command", quante: 0)
            pila.addArrangedSubview(titolo)
            pila.setCustomSpacing(10, after: titolo)
            for (combinazione, descrizione) in tasti {
                let tasti = combinazione.map {
                    Pillola($0, colore: Tema.testoPannello, sfondo: Tema.tasto, font: .systemFont(ofSize: 12, weight: .semibold))
                }
                let spazio = NSView()
                spazio.widthAnchor.constraint(equalToConstant: 6).isActive = true
                let testo = NSTextField(labelWithString: descrizione)
                testo.font = .systemFont(ofSize: 13)
                testo.textColor = Tema.testoPannello
                let riga = NSStackView(views: tasti + [spazio, testo])
                riga.spacing = 4
                pila.addArrangedSubview(riga)
                trovate += 1
            }
        }
        if trovate == 0 {
            let vuoto = NSTextField(labelWithString: "Nessuna scorciatoia per «\(filtro)».")
            vuoto.textColor = Tema.tenue
            pila.addArrangedSubview(vuoto)
        }
        animaComparsa()
    }

    /// Le schede compaiono con una breve dissolvenza.
    private func animaComparsa() {
        pila.alphaValue = 0
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.22
            c.timingFunction = CAMediaTimingFunction(name: .easeOut)
            pila.animator().alphaValue = 1
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        popola(ricerca.stringValue)
        scroll.contentView.scroll(to: .zero)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy comando: Selector) -> Bool {
        if comando == #selector(NSResponder.cancelOperation(_:)) {
            if ricerca.stringValue.isEmpty { window?.orderOut(nil) } else { ricerca.stringValue = ""; popola("") }
            return true
        }
        return false
    }

    // MARK: Inserire nell'editor

    private func inserisci(_ s: Snippet) {
        let finestra = (NSDocumentController.shared.currentDocument as? Documento)?.finestra
            ?? NSApp.orderedWindows.compactMap { $0.windowController as? FinestraController }.first
        guard let f = finestra, let w = f.window else { NSSound.beep(); return }
        w.makeKeyAndOrderFront(nil)
        w.makeFirstResponder(f.editor)
        f.editor.inserisciSnippet(s)
    }
}
