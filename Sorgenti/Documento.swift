import AppKit
import UniformTypeIdentifiers

/// Un file .c (o .h). Salvataggio, versioni, file recenti e schede li fa macOS.
@objc(Documento)
final class Documento: NSDocument {
    var testo = ""
    weak var finestra: FinestraController?

    override class var autosavesInPlace: Bool { true }

    // quando il file viene rinominato o spostato, l'albero evidenzia quello giusto
    override var fileURL: URL? {
        didSet { DispatchQueue.main.async { [weak self] in self?.finestra?.aggiornaFileAttivo() } }
    }

    /// Vero se c'è un documento aperto con modifiche non salvate per questo file.
    static func modificato(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.path
        return NSDocumentController.shared.documents.contains {
            $0.isDocumentEdited && $0.fileURL?.standardizedFileURL.path == p
        }
    }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        avvisaStato()
    }

    override func updateChangeCount(withToken token: Any, for operazione: NSDocument.SaveOperationType) {
        super.updateChangeCount(withToken: token, for: operazione)
        avvisaStato()
    }

    override func close() {
        super.close()
        NotificationCenter.default.post(name: .statoDocumenti, object: nil)
    }

    private func avvisaStato() {
        DispatchQueue.main.async { [weak self] in
            self?.finestra?.aggiornaPuntino()
            NotificationCenter.default.post(name: .statoDocumenti, object: nil)
        }
    }

    override func makeWindowControllers() {
        let c = FinestraController(documento: self)
        finestra = c
        addWindowController(c)
    }

    override func data(ofType typeName: String) throws -> Data {
        if let f = finestra { testo = f.editor.string }
        return Data(testo.utf8)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        testo = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        finestra?.ricarica()
    }

    override func prepareSavePanel(_ pannello: NSSavePanel) -> Bool {
        if fileURL == nil {
            try? FileManager.default.createDirectory(at: Impostazioni.cartellaProgrammi, withIntermediateDirectories: true)
            pannello.directoryURL = Progetto.cartellaScelta
        }
        pannello.allowedContentTypes = [.cSource, .cHeader, .plainText]
        pannello.allowsOtherFileTypes = false
        return true
    }
}
