import AppKit

/// Impostazioni… (⌘,) nel menu IDE C: aspetto, testo, compilatore, cartella del progetto.
/// Ogni modifica vale subito.
final class FinestraImpostazioni: NSWindowController, NSWindowDelegate {
    static let shared = FinestraImpostazioni()

    private let aspetto = NSSegmentedControl(labels: Aspetto.allCases.map(\.nome), trackingMode: .selectOne,
                                             target: nil, action: nil)
    private let carattere = NSPopUpButton()
    private let dimensione = NSStepper()
    private let dimensioneTesto = NSTextField(labelWithString: "")
    private let chiusura = NSButton(checkboxWithTitle: "Chiudi da solo ( ) [ ] { } \" \" ' ' e /* */", target: nil, action: nil)
    private let anteprima = NSTextField(labelWithString: "int main() { printf(\"%d\\n\", 42); }")
    private let standard = NSPopUpButton()
    private let avvisi = NSButton(checkboxWithTitle: "Mostra gli avvisi (-Wall)", target: nil, action: nil)
    private let pedantico = NSButton(checkboxWithTitle: "Segui lo standard alla lettera (-pedantic)", target: nil, action: nil)
    private let cartella = NSTextField(labelWithString: "")

    private init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Impostazioni"
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        costruisci(w)
        NotificationCenter.default.addObserver(self, selector: #selector(aggiorna), name: .dimensioneTesto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(aggiorna), name: .radiceCambiata, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    func mostra() {
        aggiorna()
        if window?.isVisible != true { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Costruzione

    private func etichetta(_ s: String) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.alignment = .right
        return t
    }

    private func nota(_ s: String) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        t.textColor = .secondaryLabelColor
        t.preferredMaxLayoutWidth = 320
        return t
    }

    private func separatore() -> NSView {
        let b = NSBox()
        b.boxType = .separator
        return b
    }

    private func costruisci(_ w: NSWindow) {
        aspetto.target = self
        aspetto.action = #selector(cambiaAspetto(_:))

        for (nome, ps) in Impostazioni.caratteriDisponibili {
            carattere.addItem(withTitle: nome)
            let f = ps.flatMap { NSFont(name: $0, size: 13) } ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
            carattere.lastItem?.attributedTitle = NSAttributedString(string: nome, attributes: [.font: f])
        }
        carattere.target = self
        carattere.action = #selector(cambiaCarattere(_:))

        dimensione.minValue = 9
        dimensione.maxValue = 32
        dimensione.increment = 1
        dimensione.valueWraps = false
        dimensione.target = self
        dimensione.action = #selector(cambiaDimensione(_:))
        dimensioneTesto.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let rigaDimensione = NSStackView(views: [dimensioneTesto, dimensione])
        rigaDimensione.spacing = 6

        anteprima.lineBreakMode = .byTruncatingTail
        anteprima.textColor = .secondaryLabelColor

        for (nome, valore) in Impostazioni.standard {
            standard.addItem(withTitle: nome)
            standard.lastItem?.representedObject = valore
        }
        standard.target = self
        standard.action = #selector(cambiaStandard(_:))
        chiusura.target = self
        chiusura.action = #selector(cambiaChiusura(_:))
        avvisi.target = self
        avvisi.action = #selector(cambiaAvvisi(_:))
        pedantico.target = self
        pedantico.action = #selector(cambiaPedantico(_:))

        cartella.lineBreakMode = .byTruncatingMiddle
        cartella.textColor = .secondaryLabelColor
        cartella.setContentCompressionResistancePriority(.init(200), for: .horizontal)
        let cambia = NSButton(title: "Cambia…", target: self, action: #selector(cambiaCartella(_:)))
        let rigaCartella = NSStackView(views: [cartella, cambia])
        rigaCartella.spacing = 8

        let griglia = NSGridView(views: [
            [etichetta("Aspetto:"), aspetto],
            [NSGridCell.emptyContentView, nota("Automatico segue il Mac (chiaro di giorno, scuro di sera se l'hai impostato).")],
            [separatore()],
            [etichetta("Carattere:"), carattere],
            [etichetta("Dimensione:"), rigaDimensione],
            [etichetta("Anteprima:"), anteprima],
            [etichetta("Scrittura:"), chiusura],
            [separatore()],
            [etichetta("Standard del C:"), standard],
            [etichetta("Compilatore:"), avvisi],
            [NSGridCell.emptyContentView, pedantico],
            [NSGridCell.emptyContentView, nota("Per gli esercizi in «C ANSI 89» scegli C89 / ANSI.")],
            [separatore()],
            [etichetta("Cartella progetto:"), rigaCartella],
        ])
        griglia.rowSpacing = 10
        griglia.columnSpacing = 10
        griglia.column(at: 0).xPlacement = .trailing
        griglia.rowAlignment = .firstBaseline
        for i in 0..<griglia.numberOfRows where griglia.cell(atColumnIndex: 0, rowIndex: i).contentView is NSBox {
            griglia.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2), verticalRange: NSRange(location: i, length: 1))
            griglia.row(at: i).topPadding = 4
            griglia.row(at: i).bottomPadding = 4
        }
        griglia.translatesAutoresizingMaskIntoConstraints = false

        let contenuto = NSView()
        contenuto.addSubview(griglia)
        NSLayoutConstraint.activate([
            griglia.topAnchor.constraint(equalTo: contenuto.topAnchor, constant: 24),
            griglia.leadingAnchor.constraint(equalTo: contenuto.leadingAnchor, constant: 28),
            griglia.trailingAnchor.constraint(equalTo: contenuto.trailingAnchor, constant: -28),
            griglia.bottomAnchor.constraint(equalTo: contenuto.bottomAnchor, constant: -24),
            rigaCartella.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            cartella.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        w.contentView = contenuto
    }

    // MARK: Valori

    @objc private func aggiorna() {
        aspetto.selectedSegment = Impostazioni.aspetto.rawValue
        carattere.selectItem(withTitle: Impostazioni.carattere)
        dimensione.doubleValue = Double(Impostazioni.dimensione)
        dimensioneTesto.stringValue = "\(Int(Impostazioni.dimensione)) pt"
        anteprima.font = Tema.mono(Impostazioni.dimensione)
        if let i = standard.itemArray.firstIndex(where: { $0.representedObject as? String == Impostazioni.standardC }) {
            standard.selectItem(at: i)
        }
        avvisi.state = Impostazioni.avvisi ? .on : .off
        chiusura.state = Impostazioni.chiusuraAutomatica ? .on : .off
        pedantico.state = Impostazioni.pedantico ? .on : .off
        cartella.stringValue = (Progetto.radice.path as NSString).abbreviatingWithTildeInPath
        cartella.toolTip = Progetto.radice.path
    }

    @objc private func cambiaAspetto(_ s: NSSegmentedControl) {
        Impostazioni.aspetto = Aspetto(rawValue: s.selectedSegment) ?? .automatico
    }

    @objc private func cambiaCarattere(_ p: NSPopUpButton) {
        if let t = p.titleOfSelectedItem { Impostazioni.carattere = t }
    }

    @objc private func cambiaDimensione(_ s: NSStepper) {
        Impostazioni.dimensione = CGFloat(s.doubleValue)
    }

    @objc private func cambiaStandard(_ p: NSPopUpButton) {
        if let v = p.selectedItem?.representedObject as? String { Impostazioni.standardC = v }
    }

    @objc private func cambiaChiusura(_ b: NSButton) { Impostazioni.chiusuraAutomatica = b.state == .on }
    @objc private func cambiaAvvisi(_ b: NSButton) { Impostazioni.avvisi = b.state == .on }
    @objc private func cambiaPedantico(_ b: NSButton) { Impostazioni.pedantico = b.state == .on }

    @objc private func cambiaCartella(_ sender: Any?) {
        guard let w = window else { return }
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.directoryURL = Progetto.radice
        p.prompt = "Usa questa cartella"
        p.beginSheetModal(for: w) { r in
            if r == .OK, let u = p.url { Progetto.radice = u }
        }
    }
}
