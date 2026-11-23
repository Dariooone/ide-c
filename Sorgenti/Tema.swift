import AppKit

/// Colori presi dai temi di JetBrains (CLion): «Dark» della New UI e «IntelliJ Light».
/// Ogni colore cambia da solo quando il Mac passa da scuro a chiaro.
enum Tema {
    private static func hex(_ v: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    private static func colore(_ scuro: UInt32, _ chiaro: UInt32) -> NSColor {
        NSColor(name: nil) { aspetto in
            aspetto.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? hex(scuro) : hex(chiaro)
        }
    }

    // finestra e pannelli
    static let editor = colore(0x1E1F22, 0xFFFFFF)
    static let pannello = colore(0x2B2D30, 0xF7F8FA)
    static let bordo = colore(0x1E1F22, 0xEBECF0)
    static let testo = colore(0xBCBEC4, 0x080808)
    static let testoPannello = colore(0xDFE1E5, 0x000000)
    static let tenue = colore(0x868A91, 0x818594)
    static let cursore = colore(0xCED0D6, 0x000000)
    static let rigaCorrente = colore(0x26282E, 0xF5F8FE)
    static let selezione = colore(0x214283, 0xA6D2FF)
    static let selezioneAlbero = colore(0x2E436E, 0xD4E2FF)
    static let selezioneAlberoSpenta = colore(0x43454A, 0xDFE1E5)
    static let numeriRiga = colore(0x4B5059, 0xAEB3C2)
    static let numeroCorrente = colore(0xA1A3AB, 0x767A8A)

    // codice
    static let parolaChiave = colore(0xCF8E6D, 0x0033B3)
    static let stringa = colore(0x6AAB73, 0x067D17)
    static let numero = colore(0x2AACB8, 0x1750EB)
    static let commento = colore(0x7A7E85, 0x8C8C8C)
    static let funzione = colore(0x56A8F5, 0x00627A)
    static let macro = colore(0xB3AE60, 0x9E880D)
    static let globale = colore(0xC77DBB, 0x871094)
    static let escape = colore(0xCF8E6D, 0x0037A6)

    // console e segnalazioni
    static let errore = colore(0xF75464, 0xE55757)
    static let avviso = colore(0xF2C55C, 0xB07A00)
    static let bene = colore(0x5FB865, 0x208A3C)
    static let input = colore(0x6AAB73, 0x067D17)
    static let infoBlu = colore(0x548AF7, 0x3574F0)

    // legenda e animazioni
    static let scheda = colore(0x1E1F22, 0xFFFFFF)
    static let schedaSopra = colore(0x2A2C31, 0xF2F6FE)
    static let bordoScheda = colore(0x393B40, 0xE4E6EB)
    static let tasto = colore(0x393B40, 0xEBECF0)
    static let lampo = colore(0x3574F0, 0x3574F0)

    // icone dell'albero
    static let cartella = colore(0x9AA7B0, 0x6C707E)
    static let fileC = colore(0x548AF7, 0x3574F0)
    static let fileH = colore(0xA571E6, 0x834DF0)
    static let fileAltro = colore(0x868A91, 0x818594)

    /// Il carattere a spaziatura fissa scelto nelle Impostazioni (SF Mono se non c'è).
    static func mono(_ dimensione: CGFloat, peso: NSFont.Weight = .regular) -> NSFont {
        let sistema = NSFont.monospacedSystemFont(ofSize: dimensione, weight: peso)
        guard let ps = Impostazioni.caratteri.first(where: { $0.0 == Impostazioni.carattere })?.1,
              let base = NSFont(name: ps, size: dimensione) else { return sistema }
        guard peso != .regular else { return base }
        return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
    }
}

/// Puntino delle modifiche non salvate (sulle schede e nell'albero). Compare con una piccola animazione.
final class Puntino: NSView {
    static let lato: CGFloat = 8
    var colore: NSColor = Tema.testoPannello

    override var intrinsicContentSize: NSSize { NSSize(width: Puntino.lato, height: Puntino.lato) }

    override func draw(_ dirtyRect: NSRect) {
        let d = min(bounds.width, bounds.height, Puntino.lato)
        let r = NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
        colore.setFill()
        NSBezierPath(ovalIn: r).fill()
    }

    /// Mostra o nasconde con una dissolvenza.
    private var obiettivo: Bool?

    func mostra(_ si: Bool, animato: Bool = true) {
        let attuale = obiettivo ?? !isHidden
        guard si != attuale else { return }         // già visibile (o sta comparendo): niente da rifare
        obiettivo = si
        if !animato {
            isHidden = !si
            alphaValue = 1
            return
        }
        if si { alphaValue = 0; isHidden = false }
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.2
            animator().alphaValue = si ? 1 : 0
        }, completionHandler: { [weak self] in
            guard let self = self, self.obiettivo == si else { return }
            if !si { self.isHidden = true; self.alphaValue = 1 }
        })
    }
}

/// Riga sottile di separazione con il colore del tema.
final class Linea: NSView {
    override func draw(_ dirtyRect: NSRect) {
        Tema.bordo.setFill()
        bounds.fill()
    }
}

/// Split view con il divisore del colore del tema.
final class Divisore: NSSplitView {
    override var dividerColor: NSColor { Tema.bordo }
}
