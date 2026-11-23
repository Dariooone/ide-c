import AppKit
import CoreServices

extension Notification.Name {
    static let fileCambiati = Notification.Name("IDEC.fileCambiati")
    static let radiceCambiata = Notification.Name("IDEC.radiceCambiata")
    /// Un documento è passato da salvato a non salvato o viceversa.
    static let statoDocumenti = Notification.Name("IDEC.statoDocumenti")
}

// MARK: - Cartella del progetto

enum Progetto {
    /// La cartella mostrata nell'albero (di solito ~/Documents/Programmi C).
    static var radice: URL {
        get {
            if let p = UserDefaults.standard.string(forKey: "radice"),
               FileManager.default.fileExists(atPath: p) {
                return URL(fileURLWithPath: p, isDirectory: true)
            }
            return Impostazioni.cartellaProgrammi
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: "radice")
            Osservatore.shared.osserva(newValue)
            NotificationCenter.default.post(name: .radiceCambiata, object: nil)
        }
    }

    /// File che si aprono nell'IDE; gli altri con l'app predefinita del Mac.
    static let estensioniTesto: Set<String> = ["c", "h", "txt"]

    /// L'ultima cartella cliccata nell'albero: lì nascono i file nuovi (⌘N) e propone «Salva».
    static var cartellaScelta: URL {
        get {
            if let p = UserDefaults.standard.string(forKey: "cartellaScelta") {
                var dir: ObjCBool = false
                let u = URL(fileURLWithPath: p, isDirectory: true).standardizedFileURL
                if FileManager.default.fileExists(atPath: p, isDirectory: &dir), dir.boolValue,
                   u.path == radice.standardizedFileURL.path || u.path.hasPrefix(radice.standardizedFileURL.path + "/") {
                    return u
                }
            }
            return radice
        }
        set { UserDefaults.standard.set(newValue.standardizedFileURL.path, forKey: "cartellaScelta") }
    }

    static var cartelleAperte: Set<String> {
        get {
            Set((UserDefaults.standard.stringArray(forKey: "cartelleAperte") ?? [])
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        }
        set { UserDefaults.standard.set(Array(newValue), forKey: "cartelleAperte") }
    }
}

/// Avvisa quando nella cartella del progetto si crea, cancella o rinomina qualcosa (FSEvents).
final class Osservatore {
    static let shared = Osservatore()
    private var flusso: FSEventStreamRef?

    func osserva(_ url: URL) {
        if let f = flusso {
            FSEventStreamStop(f)
            FSEventStreamInvalidate(f)
            FSEventStreamRelease(f)
            flusso = nil
        }
        let richiamo: FSEventStreamCallback = { _, _, quanti, _, segni, _ in
            let interessa = FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved
                | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagRootChanged)
            for i in 0..<quanti where segni[i] & interessa != 0 {
                NotificationCenter.default.post(name: .fileCambiati, object: nil)
                return
            }
        }
        var contesto = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        guard let f = FSEventStreamCreate(nil, richiamo, &contesto, [url.path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3,
                                          FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot))
        else { return }
        FSEventStreamSetDispatchQueue(f, .main)
        FSEventStreamStart(f)
        flusso = f
    }
}

// MARK: - Operazioni sui file (coordinate, così i file aperti seguono gli spostamenti)

enum OperazioniFile {
    static func sposta(_ da: URL, _ a: URL) throws {
        var erroreCoord: NSError?
        var errore: Error?
        let c = NSFileCoordinator()
        c.coordinate(writingItemAt: da, options: .forMoving, writingItemAt: a, options: .forReplacing,
                     error: &erroreCoord) { d, dd in
            do {
                c.item(at: d, willMoveTo: dd)
                try FileManager.default.moveItem(at: d, to: dd)
                c.item(at: d, didMoveTo: dd)
            } catch { errore = error }
        }
        if let e = erroreCoord ?? errore { throw e }
        aggiornaDocumenti(da: da, a: a)
    }

    /// Se un file aperto (o una cartella che lo contiene) è stato spostato, la finestra segue il nuovo percorso.
    static func aggiornaDocumenti(da: URL, a: URL?) {
        let vecchio = da.standardizedFileURL.path
        for d in NSDocumentController.shared.documents {
            guard let u = d.fileURL?.standardizedFileURL.path else { continue }
            guard u == vecchio || u.hasPrefix(vecchio + "/") else { continue }
            if let a = a {
                d.fileURL = URL(fileURLWithPath: a.standardizedFileURL.path + u.dropFirst(vecchio.count))
            } else {
                d.close()
            }
        }
    }

    static func copia(_ da: URL, _ a: URL) throws {
        var erroreCoord: NSError?
        var errore: Error?
        NSFileCoordinator().coordinate(readingItemAt: da, options: [], writingItemAt: a, options: .forReplacing,
                                       error: &erroreCoord) { d, dd in
            do { try FileManager.default.copyItem(at: d, to: dd) } catch { errore = error }
        }
        if let e = erroreCoord ?? errore { throw e }
    }

    static func cestino(_ url: URL) throws {
        var erroreCoord: NSError?
        var errore: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &erroreCoord) { u in
            do { try FileManager.default.trashItem(at: u, resultingItemURL: nil) } catch { errore = error }
        }
        if let e = erroreCoord ?? errore { throw e }
        aggiornaDocumenti(da: url, a: nil)
    }

    /// «nome.c» se è libero, altrimenti «nome 2.c», «nome 3.c»…
    /// Vero se i due percorsi portano allo stesso file (es. differiscono solo per maiuscole/minuscole).
    static func stessoFile(_ a: URL, _ b: URL) -> Bool {
        guard let ia = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let ib = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        else { return false }
        return ia.isEqual(ib)
    }

    static func libero(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let cartella = url.deletingLastPathComponent()
        let est = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var n = 2
        while true {
            let nome = est.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(est)"
            let u = cartella.appendingPathComponent(nome)
            if !FileManager.default.fileExists(atPath: u.path) { return u }
            n += 1
        }
    }
}

// MARK: - Nodi dell'albero

final class Nodo: NSObject {
    let url: URL
    let cartella: Bool
    weak var genitore: Nodo?
    private var caricati: [Nodo]?

    init(url: URL, cartella: Bool, genitore: Nodo?) {
        self.url = url.standardizedFileURL
        self.cartella = cartella
        self.genitore = genitore
    }

    var nome: String { url.lastPathComponent }

    var figli: [Nodo] {
        if let c = caricati { return c }
        let c = carica()
        caricati = c
        return c
    }

    private func carica() -> [Nodo] {
        guard cartella, let voci = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey], options: [.skipsHiddenFiles])
        else { return [] }
        return voci.map { u in
            let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return Nodo(url: u, cartella: (v?.isDirectory ?? false) && !(v?.isPackage ?? false), genitore: self)
        }.sorted { a, b in
            a.cartella != b.cartella ? a.cartella
                : a.nome.localizedStandardCompare(b.nome) == .orderedAscending
        }
    }
}

// MARK: - Viste

final class CellaFile: NSTableCellView {
    private let icona = NSImageView()
    private let nome = NSTextField(labelWithString: "")
    private let puntino = Puntino()
    private var url: URL?

    init() {
        super.init(frame: .zero)
        puntino.isHidden = true
        puntino.toolTip = "Modifiche non ancora salvate"
        for v in [icona, nome, puntino] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        nome.lineBreakMode = .byTruncatingMiddle
        nome.font = .systemFont(ofSize: 13)
        icona.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        imageView = icona
        textField = nome
        NSLayoutConstraint.activate([
            icona.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            icona.centerYAnchor.constraint(equalTo: centerYAnchor),
            icona.widthAnchor.constraint(equalToConstant: 18),
            nome.leadingAnchor.constraint(equalTo: icona.trailingAnchor, constant: 6),
            nome.centerYAnchor.constraint(equalTo: centerYAnchor),
            puntino.leadingAnchor.constraint(equalTo: nome.trailingAnchor, constant: 7),
            puntino.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            puntino.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        nome.setContentCompressionResistancePriority(.init(250), for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    func mostra(_ n: Nodo) {
        let est = n.url.pathExtension.lowercased()
        let (simbolo, colore): (String, NSColor)
        if n.cartella { (simbolo, colore) = ("folder.fill", Tema.cartella) }
        else if est == "c" { (simbolo, colore) = ("c.square.fill", Tema.fileC) }
        else if est == "h" { (simbolo, colore) = ("h.square.fill", Tema.fileH) }
        else if est == "txt" { (simbolo, colore) = ("doc.plaintext", Tema.fileAltro) }
        else { (simbolo, colore) = ("doc", Tema.fileAltro) }
        icona.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: nil)
        icona.contentTintColor = colore
        nome.stringValue = n.nome
        nome.textColor = Tema.testoPannello
        let stesso = url == n.url
        url = n.url
        puntino.mostra(!n.cartella && Documento.modificato(n.url), animato: stesso)
    }
}

final class RigaAlbero: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        (isEmphasized ? Tema.selezioneAlbero : Tema.selezioneAlberoSpenta).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}

final class VistaAlbero: NSOutlineView {
    var invio: (() -> Void)?
    var cancella: (() -> Void)?

    /// Spazio tra il bordo sinistro e la freccia delle cartelle.
    static let margine: CGFloat = 10

    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        var r = super.frameOfOutlineCell(atRow: row)
        if !r.isEmpty { r.origin.x += VistaAlbero.margine }
        return r
    }

    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        var r = super.frameOfCell(atColumn: column, row: row)
        r.origin.x += VistaAlbero.margine
        r.size.width = max(0, r.width - VistaAlbero.margine)
        return r
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { invio?(); return }                        // Invio
        if event.keyCode == 51, event.modifierFlags.contains(.command) { cancella?(); return }   // ⌘⌫
        super.keyDown(with: event)
    }
}

extension NSLayoutConstraint {
    func conPriorita(_ p: Float) -> NSLayoutConstraint {
        priority = NSLayoutConstraint.Priority(p)
        return self
    }
}

// MARK: - Pannello con l'albero

final class PannelloFile: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
    weak var finestra: NSWindow?
    /// Il file della finestra: viene evidenziato nell'albero.
    var fileAttivo: URL? { didSet { seleziona(fileAttivo) } }

    private let titolo = NSTextField(labelWithString: "")
    private let albero = VistaAlbero()
    private let scroll = NSScrollView()
    private var radice = Nodo(url: Progetto.radice, cartella: true, genitore: nil)
    private var firmaAttuale: [String] = []
    private var staRicaricando = false
    private var selezioneDaCodice = false
    private static let idCella = NSUserInterfaceItemIdentifier("cella")

    override init(frame: NSRect) {
        super.init(frame: frame)
        costruisci()
        ricarica(forza: true)
        NotificationCenter.default.addObserver(self, selector: #selector(cambiati), name: .fileCambiati, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(radiceCambiata), name: .radiceCambiata, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(aggiornaPuntini), name: .statoDocumenti, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    // niente sfondo pieno: dietro c'è il materiale traslucido della sidebar di macOS

    private func bottone(_ simbolo: String, _ suggerimento: String, _ azione: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: simbolo, accessibilityDescription: suggerimento)!,
                         target: self, action: azione)
        b.isBordered = false
        b.bezelStyle = .regularSquare
        b.contentTintColor = Tema.tenue
        b.toolTip = suggerimento
        b.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        return b
    }

    private func costruisci() {
        clipsToBounds = true          // mentre la colonna si chiude, niente esce dai bordi
        titolo.font = .systemFont(ofSize: 13, weight: .semibold)
        titolo.textColor = Tema.testoPannello
        titolo.lineBreakMode = .byTruncatingTail
        titolo.setContentCompressionResistancePriority(.init(100), for: .horizontal)

        let bottoni = NSStackView(views: [
            bottone("doc.badge.plus", "Nuovo file C", #selector(nuovoFile(_:))),
            bottone("folder.badge.plus", "Nuova cartella", #selector(nuovaCartella(_:))),
            bottone("arrow.down.right.and.arrow.up.left", "Chiudi tutte le cartelle", #selector(chiudiTutto(_:))),
            bottone("folder", "Scegli la cartella del progetto…", #selector(scegliRadice(_:))),
        ])
        bottoni.spacing = 8

        let colonna = NSTableColumn(identifier: .init("nome"))
        colonna.resizingMask = .autoresizingMask
        albero.addTableColumn(colonna)
        albero.outlineTableColumn = colonna
        albero.headerView = nil
        albero.style = .plain
        albero.rowHeight = 24
        albero.indentationPerLevel = 14
        albero.backgroundColor = .clear
        albero.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        albero.focusRingType = .none
        albero.dataSource = self
        albero.delegate = self
        albero.target = self
        albero.doubleAction = #selector(doppioClic(_:))
        albero.registerForDraggedTypes([.fileURL])
        albero.setDraggingSourceOperationMask(.move, forLocal: true)
        albero.setDraggingSourceOperationMask(.copy, forLocal: false)
        albero.invio = { [weak self] in if let n = self?.selezionato { self?.apri(n) } }
        albero.cancella = { [weak self] in if let n = self?.selezionato { self?.cestino(n) } }
        let menu = NSMenu()
        menu.delegate = self
        albero.menu = menu

        scroll.documentView = albero
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        for v in [titolo, bottoni, scroll] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            titolo.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            titolo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            bottoni.centerYAnchor.constraint(equalTo: titolo.centerYAnchor),
            bottoni.leadingAnchor.constraint(greaterThanOrEqualTo: titolo.trailingAnchor, constant: 8).conPriorita(100),
            bottoni.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).conPriorita(100),
            scroll.topAnchor.constraint(equalTo: titolo.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: Caricamento

    @objc private func cambiati() { ricarica(forza: false) }

    /// Aggiorna solo i puntini delle righe visibili (senza ricaricare l'albero).
    @objc private func aggiornaPuntini() {
        let righe = albero.rows(in: albero.visibleRect)
        guard righe.length > 0 else { return }
        for r in righe.location..<NSMaxRange(righe) {
            if let n = albero.item(atRow: r) as? Nodo, let cella = albero.view(atColumn: 0, row: r, makeIfNecessary: false) as? CellaFile {
                cella.mostra(n)
            }
        }
    }

    @objc private func radiceCambiata() { ricarica(forza: true) }

    /// Elenco dei percorsi visibili: se non cambia, l'albero non si ridisegna.
    private func firma(_ n: Nodo, _ aperte: Set<String>) -> [String] {
        var r: [String] = []
        for f in n.figli {
            r.append(f.url.path)
            if f.cartella, aperte.contains(f.url.path) { r += firma(f, aperte) }
        }
        return r
    }

    func ricarica(forza: Bool) {
        let nuova = Nodo(url: Progetto.radice, cartella: true, genitore: nil)
        let aperte = Progetto.cartelleAperte
        let nuovaFirma = firma(nuova, aperte)
        if !forza, nuovaFirma == firmaAttuale, nuova.url == radice.url { return }
        radice = nuova
        firmaAttuale = nuovaFirma
        titolo.stringValue = radice.nome
        titolo.toolTip = radice.url.path
        staRicaricando = true
        albero.reloadData()
        func espandi(_ nodi: [Nodo]) {
            for n in nodi where n.cartella && aperte.contains(n.url.path) {
                albero.expandItem(n)
                espandi(n.figli)
            }
        }
        espandi(radice.figli)
        staRicaricando = false
        seleziona(fileAttivo)
    }

    private func seleziona(_ url: URL?) {
        guard let url = url?.standardizedFileURL else { return }
        let base = radice.url.path
        selezioneDaCodice = true
        defer { selezioneDaCodice = false }
        guard url.path.hasPrefix(base + "/") else { albero.deselectAll(nil); return }
        var nodo = radice
        let parti = url.path.dropFirst(base.count + 1).split(separator: "/").map(String.init)
        for (i, p) in parti.enumerated() {
            guard let f = nodo.figli.first(where: { $0.nome == p }) else { return }
            if i < parti.count - 1 { albero.expandItem(f) }
            nodo = f
        }
        let riga = albero.row(forItem: nodo)
        if riga >= 0 {
            albero.selectRowIndexes([riga], byExtendingSelection: false)
            albero.scrollRowToVisible(riga)
        }
    }

    // MARK: Data source e delegate

    func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        ((item as? Nodo) ?? radice).figli.count
    }

    func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        ((item as? Nodo) ?? radice).figli[index]
    }

    func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? Nodo)?.cartella ?? false
    }

    func outlineView(_ ov: NSOutlineView, viewFor colonna: NSTableColumn?, item: Any) -> NSView? {
        let cella = ov.makeView(withIdentifier: PannelloFile.idCella, owner: self) as? CellaFile ?? {
            let c = CellaFile()
            c.identifier = PannelloFile.idCella
            return c
        }()
        cella.mostra(item as! Nodo)
        return cella
    }

    func outlineView(_ ov: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? { RigaAlbero() }

    /// Quando sei tu a cliccare, ricorda la cartella (quella cliccata o quella del file cliccato).
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !selezioneDaCodice, !staRicaricando, let n = selezionato else { return }
        Progetto.cartellaScelta = cartella(per: n)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !staRicaricando, let n = notification.userInfo?["NSObject"] as? Nodo else { return }
        Progetto.cartelleAperte.insert(n.url.path)
        firmaAttuale = firma(radice, Progetto.cartelleAperte)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !staRicaricando, let n = notification.userInfo?["NSObject"] as? Nodo else { return }
        Progetto.cartelleAperte.remove(n.url.path)
        firmaAttuale = firma(radice, Progetto.cartelleAperte)
    }

    // MARK: Trascinare per spostare (e dal Finder per copiare)

    func outlineView(_ ov: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        (item as? Nodo)?.url as NSURL?
    }

    private func trascinati(_ info: NSDraggingInfo) -> [URL] {
        (info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    private func destinazione(_ item: Any?) -> Nodo {
        guard let n = item as? Nodo else { return radice }
        return n.cartella ? n : (n.genitore ?? radice)
    }

    func outlineView(_ ov: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?,
                     proposedChildIndex index: Int) -> NSDragOperation {
        let dest = destinazione(item)
        ov.setDropItem(dest === radice ? nil : dest, dropChildIndex: NSOutlineViewDropOnItemIndex)
        let urls = trascinati(info)
        guard !urls.isEmpty else { return [] }
        let interno = (info.draggingSource as? NSOutlineView) === ov
        for u in urls.map({ $0.standardizedFileURL }) {
            if dest.url.path == u.path || dest.url.path.hasPrefix(u.path + "/") { return [] }   // dentro sé stessa
            if interno, u.deletingLastPathComponent().path == dest.url.path { return [] }       // stessa cartella
        }
        return interno ? .move : .copy
    }

    func outlineView(_ ov: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let dest = destinazione(item)
        let interno = (info.draggingSource as? NSOutlineView) === ov
        for u in trascinati(info) {
            let a = OperazioniFile.libero(dest.url.appendingPathComponent(u.lastPathComponent))
            do {
                if interno { try OperazioniFile.sposta(u, a) } else { try OperazioniFile.copia(u, a) }
            } catch { mostraErrore(error); return false }
        }
        Progetto.cartelleAperte.insert(dest.url.path)
        ricarica(forza: true)
        return true
    }

    // MARK: Menu col tasto destro

    private var selezionato: Nodo? {
        albero.selectedRow >= 0 ? albero.item(atRow: albero.selectedRow) as? Nodo : nil
    }

    private func nodo(_ sender: Any?) -> Nodo? {
        if let n = (sender as? NSMenuItem)?.representedObject as? Nodo { return n }
        if sender is NSMenuItem { return nil }          // clic destro nel vuoto: cartella del progetto
        return selezionato
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let riga = albero.clickedRow
        let n = riga >= 0 ? albero.item(atRow: riga) as? Nodo : nil
        func voce(_ titolo: String, _ azione: Selector) {
            let v = NSMenuItem(title: titolo, action: azione, keyEquivalent: "")
            v.target = self
            v.representedObject = n
            menu.addItem(v)
        }
        if let n = n, !n.cartella { voce("Apri", #selector(apriVoce(_:))); menu.addItem(.separator()) }
        voce("Nuovo file C…", #selector(nuovoFile(_:)))
        voce("Nuova cartella…", #selector(nuovaCartella(_:)))
        menu.addItem(.separator())
        if n != nil {
            voce("Rinomina…", #selector(rinomina(_:)))
            voce("Duplica", #selector(duplica(_:)))
            voce("Copia percorso", #selector(copiaPercorso(_:)))
            menu.addItem(.separator())
        }
        voce("Mostra nel Finder", #selector(mostraNelFinder(_:)))
        voce("Apri nel Terminale", #selector(apriNelTerminale(_:)))
        if n != nil {
            menu.addItem(.separator())
            voce("Sposta nel Cestino", #selector(cestinoVoce(_:)))
        }
    }

    // MARK: Azioni

    private func cartella(per n: Nodo?) -> URL {
        guard let n = n else { return radice.url }
        return n.cartella ? n.url : n.url.deletingLastPathComponent()
    }

    @objc private func doppioClic(_ sender: Any?) {
        guard albero.clickedRow >= 0, let n = albero.item(atRow: albero.clickedRow) as? Nodo else { return }
        apri(n)
    }

    @objc private func apriVoce(_ sender: Any?) { if let n = nodo(sender) { apri(n) } }

    func apri(_ n: Nodo) {
        if n.cartella {
            albero.isItemExpanded(n) ? albero.collapseItem(n) : albero.expandItem(n)
            return
        }
        if Progetto.estensioniTesto.contains(n.url.pathExtension.lowercased()) {
            NSDocumentController.shared.openDocument(withContentsOf: n.url, display: true) { [weak self] _, _, errore in
                if let e = errore { self?.mostraErrore(e) }
            }
        } else {
            NSWorkspace.shared.open(n.url)
        }
    }

    /// Cartella di destinazione: dal tasto destro quella cliccata, altrimenti l'ultima scelta da te.
    private func destinazioneNuovo(_ sender: Any?) -> URL {
        if sender is NSMenuItem, albero.menu?.items.contains(where: { $0 === sender as AnyObject }) == true {
            return cartella(per: nodo(sender))
        }
        return Progetto.cartellaScelta
    }

    @objc func nuovoFile(_ sender: Any?) {
        let dove = destinazioneNuovo(sender)
        chiediNome("Nuovo file C", "In «\(dove.lastPathComponent)». Senza estensione diventa .c", iniziale: "esercizio.c",
                   pulsante: "Crea") { [weak self] nome in
            let nomeFile = (nome as NSString).pathExtension.isEmpty ? nome + ".c" : nome
            let url = dove.appendingPathComponent(nomeFile)
            guard !FileManager.default.fileExists(atPath: url.path) else {
                self?.mostraMessaggio("Esiste già un file chiamato «\(nomeFile)».")
                return
            }
            guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
                self?.mostraMessaggio("Non riesco a creare «\(nomeFile)».")
                return
            }
            Progetto.cartelleAperte.insert(dove.standardizedFileURL.path)
            self?.ricarica(forza: true)
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }

    @objc func nuovaCartella(_ sender: Any?) {
        let dove = destinazioneNuovo(sender)
        chiediNome("Nuova cartella", "In «\(dove.lastPathComponent)»", iniziale: "Nuova cartella",
                   pulsante: "Crea") { [weak self] nome in
            let url = dove.appendingPathComponent(nome, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                Progetto.cartelleAperte.insert(dove.standardizedFileURL.path)
                self?.ricarica(forza: true)
                self?.seleziona(url)
            } catch { self?.mostraErrore(error) }
        }
    }

    @objc private func rinomina(_ sender: Any?) {
        guard let n = nodo(sender) else { return }
        chiediNome("Rinomina", "Nuovo nome per «\(n.nome)»", iniziale: n.nome, pulsante: "Rinomina") { [weak self] nome in
            guard nome != n.nome else { return }
            let a = n.url.deletingLastPathComponent().appendingPathComponent(nome)
            // sul Mac «esercizio.c» e «Esercizio.c» sono lo stesso file: cambiare solo maiuscole è permesso
            guard !FileManager.default.fileExists(atPath: a.path) || OperazioniFile.stessoFile(n.url, a) else {
                self?.mostraMessaggio("Esiste già «\(nome)» in questa cartella.")
                return
            }
            do {
                try OperazioniFile.sposta(n.url, a)
                if n.cartella, Progetto.cartelleAperte.contains(n.url.path) {
                    Progetto.cartelleAperte.remove(n.url.path)
                    Progetto.cartelleAperte.insert(a.standardizedFileURL.path)
                }
                self?.ricarica(forza: true)
                self?.seleziona(a)
            } catch { self?.mostraErrore(error) }
        }
    }

    @objc private func duplica(_ sender: Any?) {
        guard let n = nodo(sender) else { return }
        let est = n.url.pathExtension
        let base = n.url.deletingPathExtension().lastPathComponent + " copia"
        let a = OperazioniFile.libero(n.url.deletingLastPathComponent()
            .appendingPathComponent(est.isEmpty ? base : base + "." + est))
        do {
            try OperazioniFile.copia(n.url, a)
            ricarica(forza: true)
            seleziona(a)
        } catch { mostraErrore(error) }
    }

    @objc private func copiaPercorso(_ sender: Any?) {
        guard let n = nodo(sender) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(n.url.path, forType: .string)
    }

    @objc private func mostraNelFinder(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting([nodo(sender)?.url ?? radice.url])
    }

    @objc private func apriNelTerminale(_ sender: Any?) {
        let terminale = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([cartella(per: nodo(sender))], withApplicationAt: terminale,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func cestinoVoce(_ sender: Any?) { if let n = nodo(sender) { cestino(n) } }

    private func cestino(_ n: Nodo) {
        guard let w = finestra else { return }
        let a = NSAlert()
        a.messageText = "Spostare «\(n.nome)» nel Cestino?"
        a.informativeText = n.cartella ? "Con tutto quello che contiene. Puoi recuperarla dal Cestino."
                                       : "Puoi recuperarlo dal Cestino."
        a.addButton(withTitle: "Sposta nel Cestino")
        a.addButton(withTitle: "Annulla")
        a.beginSheetModal(for: w) { [weak self] r in
            guard r == .alertFirstButtonReturn else { return }
            do {
                try OperazioniFile.cestino(n.url)
                self?.ricarica(forza: true)
            } catch { self?.mostraErrore(error) }
        }
    }

    @objc private func chiudiTutto(_ sender: Any?) {
        albero.collapseItem(nil, collapseChildren: true)
        Progetto.cartelleAperte = []
        firmaAttuale = firma(radice, [])
    }

    @objc func scegliRadice(_ sender: Any?) {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.directoryURL = radice.url
        p.prompt = "Usa questa cartella"
        p.message = "Scegli la cartella da mostrare a sinistra"
        let fatto: (NSApplication.ModalResponse) -> Void = { r in
            if r == .OK, let u = p.url { Progetto.radice = u }
        }
        if let w = finestra { p.beginSheetModal(for: w, completionHandler: fatto) } else { fatto(p.runModal()) }
    }

    // MARK: Finestre di dialogo

    private func chiediNome(_ titolo: String, _ messaggio: String, iniziale: String, pulsante: String,
                            _ fatto: @escaping (String) -> Void) {
        guard let w = finestra else { return }
        let a = NSAlert()
        a.messageText = titolo
        a.informativeText = messaggio
        a.addButton(withTitle: pulsante)
        a.addButton(withTitle: "Annulla")
        let campo = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        campo.stringValue = iniziale
        a.accessoryView = campo
        a.window.initialFirstResponder = campo
        a.beginSheetModal(for: w) { r in
            guard r == .alertFirstButtonReturn else { return }
            let nome = campo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nome.isEmpty, !nome.contains("/"), !nome.hasPrefix(".") else { return }
            fatto(nome)
        }
        DispatchQueue.main.async {
            let base = (iniziale as NSString).deletingPathExtension
            campo.currentEditor()?.selectedRange = NSRange(location: 0, length: base.utf16.count)
        }
    }

    private func mostraErrore(_ e: Error) {
        guard let w = finestra else { return }
        NSAlert(error: e).beginSheetModal(for: w)
    }

    private func mostraMessaggio(_ testo: String) {
        guard let w = finestra else { return }
        let a = NSAlert()
        a.messageText = testo
        a.beginSheetModal(for: w)
    }
}
