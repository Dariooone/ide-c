import AppKit

// MARK: - Impostazioni

extension Notification.Name {
    /// Cambiati dimensione o carattere del testo.
    static let dimensioneTesto = Notification.Name("IDEC.dimensioneTesto")
}

/// Aspetto dell'app: segue il Mac, sempre chiaro o sempre scuro.
enum Aspetto: Int, CaseIterable {
    case automatico = 0, chiaro, scuro
    var nome: String { ["Automatico", "Chiaro", "Scuro"][rawValue] }
    func applica() {
        switch self {
        case .automatico: NSApp.appearance = nil
        case .chiaro: NSApp.appearance = NSAppearance(named: .aqua)
        case .scuro: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum Impostazioni {
    static let dimensioneNormale: CGFloat = 13

    static var dimensione: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "dimensione")
            return v > 0 ? CGFloat(v) : dimensioneNormale
        }
        set {
            UserDefaults.standard.set(Double(min(max(newValue, 9), 32)), forKey: "dimensione")
            NotificationCenter.default.post(name: .dimensioneTesto, object: nil)
        }
    }

    static var font: NSFont { Tema.mono(dimensione) }

    static var aspetto: Aspetto {
        get { Aspetto(rawValue: UserDefaults.standard.integer(forKey: "aspetto")) ?? .automatico }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "aspetto"); newValue.applica() }
    }

    /// Caratteri a spaziatura fissa tra cui scegliere: (nome mostrato, nome PostScript; nil = SF Mono di sistema).
    static let caratteri: [(String, String?)] = [("SF Mono", nil), ("JetBrains Mono", "JetBrainsMono-Regular"),
                                                 ("Menlo", "Menlo-Regular"), ("Monaco", "Monaco"),
                                                 ("Courier New", "CourierNewPSMT")]
    static var caratteriDisponibili: [(String, String?)] {
        caratteri.filter { $0.1 == nil || NSFont(name: $0.1!, size: 12) != nil }
    }
    /// Nome mostrato del carattere scelto (di base JetBrains Mono se c'è, altrimenti SF Mono).
    static var carattere: String {
        get {
            if let c = UserDefaults.standard.string(forKey: "carattere"), caratteriDisponibili.contains(where: { $0.0 == c }) {
                return c
            }
            return caratteriDisponibili.contains(where: { $0.0 == "JetBrains Mono" }) ? "JetBrains Mono" : "SF Mono"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "carattere")
            NotificationCenter.default.post(name: .dimensioneTesto, object: nil)
        }
    }

    /// Standard del C passato a clang (-std=…).
    static let standard: [(String, String)] = [("C89 / ANSI", "c89"), ("C99", "c99"), ("C11", "c11"), ("C17", "c17")]
    static var standardC: String {
        get { UserDefaults.standard.string(forKey: "standardC") ?? "c11" }
        set { UserDefaults.standard.set(newValue, forKey: "standardC") }
    }
    static var avvisi: Bool {
        get { UserDefaults.standard.object(forKey: "avvisi") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "avvisi") }
    }
    /// Chiude da sola ( [ { " ' e /* */ mentre scrivi.
    static var chiusuraAutomatica: Bool {
        get { UserDefaults.standard.object(forKey: "chiusuraAutomatica") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "chiusuraAutomatica") }
    }
    static var pedantico: Bool {
        get { UserDefaults.standard.bool(forKey: "pedantico") }
        set { UserDefaults.standard.set(newValue, forKey: "pedantico") }
    }

    static var cartellaProgrammi: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Programmi C", isDirectory: true)
    }

    static func paragrafo(_ font: NSFont) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        let spazio = (" " as NSString).size(withAttributes: [.font: font]).width
        p.tabStops = []
        p.defaultTabInterval = spazio * 4
        return p
    }
}

// MARK: - Colori del codice (come CLion)

final class Colorazione: NSObject, NSTextStorageDelegate {
    static let regola = try! NSRegularExpression(
        pattern: #"(/\*[\s\S]*?(?:\*/|\z)|//[^\n]*)|("(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?)|(^[ \t]*#[ \t]*[A-Za-z]+)|((?<=include)[ \t]*<[^>\n]*>)|(\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)[uUlLfF]*)|\b([A-Za-z_]\w*)"#,
        options: [.anchorsMatchLines])
    /// \n, \t … e %d, %5.2f … dentro le stringhe
    static let speciali = try! NSRegularExpression(
        pattern: #"\\.|%[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|L|z|j|t)?[diouxXfFeEgGaAcspn%]"#)
    static let maiuscole = try! NSRegularExpression(pattern: #"^[A-Z][A-Z0-9_]+$"#)

    static let paroleChiave: Set<String> = [
        "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
        "return", "goto", "sizeof", "typedef", "struct", "union", "enum", "static", "const",
        "extern", "volatile", "register", "auto", "inline", "restrict",
        "int", "char", "float", "double", "void", "long", "short", "unsigned", "signed", "_Bool",
    ]
    static let costanti: Set<String> = ["NULL", "EOF", "true", "false", "bool", "RAND_MAX", "EXIT_SUCCESS", "EXIT_FAILURE"]
    static let globali: Set<String> = ["stdin", "stdout", "stderr", "errno"]

    var font = Impostazioni.font

    func textStorage(_ ts: NSTextStorage, didProcessEditing azioni: NSTextStorageEditActions,
                     range: NSRange, changeInLength: Int) {
        if azioni.contains(.editedCharacters) { colora(ts) }
    }

    func colora(_ ts: NSTextStorage) {
        let testo = ts.string
        let ns = testo as NSString
        let tutto = NSRange(location: 0, length: ns.length)
        ts.addAttributes([.foregroundColor: Tema.testo, .font: font,
                          .paragraphStyle: Impostazioni.paragrafo(font)], range: tutto)
        var dopoDefine = false
        Colorazione.regola.enumerateMatches(in: testo, range: tutto) { m, _, _ in
            guard let m = m else { return }
            func c(_ r: NSRange, _ colore: NSColor) { ts.addAttribute(.foregroundColor, value: colore, range: r) }
            let commento = m.range(at: 1), stringa = m.range(at: 2), direttiva = m.range(at: 3)
            let intestazione = m.range(at: 4), numero = m.range(at: 5), parola = m.range(at: 6)
            if commento.location != NSNotFound { c(commento, Tema.commento); return }
            if stringa.location != NSNotFound {
                c(stringa, Tema.stringa)
                Colorazione.speciali.enumerateMatches(in: testo, range: stringa) { s, _, _ in
                    if let s = s { c(s.range, Tema.escape) }
                }
                return
            }
            if direttiva.location != NSNotFound {
                c(direttiva, Tema.parolaChiave)
                dopoDefine = ns.substring(with: direttiva).hasSuffix("define")
                return
            }
            if intestazione.location != NSNotFound { c(intestazione, Tema.stringa); return }
            if numero.location != NSNotFound { c(numero, Tema.numero); return }
            guard parola.location != NSNotFound else { return }
            let p = ns.substring(with: parola)
            defer { dopoDefine = false }
            if dopoDefine || Colorazione.costanti.contains(p)
                || Colorazione.maiuscole.firstMatch(in: p, range: NSRange(location: 0, length: parola.length)) != nil {
                c(parola, Tema.macro)
            } else if Colorazione.paroleChiave.contains(p) {
                c(parola, Tema.parolaChiave)
            } else if Colorazione.globali.contains(p) {
                c(parola, Tema.globale)
            } else {
                var i = NSMaxRange(parola)
                while i < ns.length, ns.character(at: i) == 32 || ns.character(at: i) == 9 { i += 1 }
                if i < ns.length, ns.character(at: i) == 40 /* ( */ { c(parola, Tema.funzione) }
            }
        }
    }
}

// MARK: - Editor con scorciatoie

final class EditorC: NSTextView {
    static let rientro = "    "

    /// Punto da riempire in cui sei adesso e quelli che seguono (l'ultimo è $0).
    private var attuale: NSRange?
    private var restanti: [NSRange] = []

    func fineSessione() {
        attuale = nil
        restanti = []
    }

    // Riga dove sta il cursore, con lo sfondo leggermente diverso (come in CLion)
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard selectedRange().length == 0, let lm = layoutManager else { return }
        let ns = string as NSString
        let pos = selectedRange().location
        var riga: NSRect
        if ns.length == 0 || (pos >= ns.length && ns.character(at: ns.length - 1) == 10) {
            riga = lm.extraLineFragmentRect
        } else {
            riga = lm.lineFragmentRect(forGlyphAt: lm.glyphIndexForCharacter(at: min(pos, ns.length - 1)), effectiveRange: nil)
        }
        riga.origin.x = 0
        riga.origin.y += textContainerOrigin.y
        riga.size.width = bounds.width
        Tema.rigaCorrente.setFill()
        riga.intersection(rect).fill()
    }

    override func setSelectedRanges(_ r: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(r, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
    }

    // Nessun completamento automatico: niente aiuti.
    override func complete(_ sender: Any?) {}

    override func cancelOperation(_ sender: Any?) { fineSessione() }

    override func mouseDown(with event: NSEvent) {
        fineSessione()
        super.mouseDown(with: event)
    }

    /// Tiene aggiornate le posizioni dei punti mentre scrivi dentro quello attuale.
    override func shouldChangeText(in r: NSRange, replacementString s: String?) -> Bool {
        guard super.shouldChangeText(in: r, replacementString: s) else { return false }
        if let a = attuale {
            if let s = s, r.location >= a.location, NSMaxRange(r) <= NSMaxRange(a) {
                let delta = (s as NSString).length - r.length
                let fineVecchia = NSMaxRange(a)
                attuale = NSRange(location: a.location, length: a.length + delta)
                restanti = restanti.map {
                    $0.location >= fineVecchia ? NSRange(location: $0.location + delta, length: $0.length) : $0
                }
            } else {
                fineSessione()
            }
        }
        return true
    }

    // MARK: Tab

    override func insertTab(_ sender: Any?) {
        let sel = selectedRange()
        if sel.length == 0, let (parola, r) = parolaPrima(sel.location),
           let snippet = SNIPPET.first(where: { $0.parola == parola }) {
            inserisci(snippet, al: r)
            return
        }
        if attuale != nil {
            prossimoPunto()
            return
        }
        if sel.length > 0, (string as NSString).substring(with: sel).contains("\n") {
            spostaRighe(avanti: true)
            return
        }
        insertText(EditorC.rientro, replacementRange: sel)
    }

    override func insertBacktab(_ sender: Any?) {
        fineSessione()
        spostaRighe(avanti: false)
    }

    private func parolaPrima(_ posizione: Int) -> (String, NSRange)? {
        let ns = string as NSString
        var i = posizione
        func lettera(_ c: unichar) -> Bool {
            (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95
        }
        while i > 0, lettera(ns.character(at: i - 1)) { i -= 1 }
        guard i < posizione else { return nil }
        let r = NSRange(location: i, length: posizione - i)
        return (ns.substring(with: r), r)
    }

    private func inserisci(_ snippet: Snippet, al r: NSRange) {
        let ns = string as NSString
        let inizioRiga = ns.lineRange(for: NSRange(location: r.location, length: 0)).location
        let prima = ns.substring(with: NSRange(location: inizioRiga, length: r.location - inizioRiga))
        let rientroRiga = String(prima.prefix { $0 == " " || $0 == "\t" })
        let e = espandi(snippet.testo, rientro: rientroRiga)
        insertText(e.testo, replacementRange: r)          // sposta anche i punti di un'eventuale sessione aperta
        let nuovi = e.punti.map { NSRange(location: $0.location + r.location, length: $0.length) }
        lampeggia(NSRange(location: r.location, length: e.testo.utf16.count))
        vaiA(nuovi + restanti)
    }

    /// Inserisce una scorciatoia dove sta il cursore (dalla legenda).
    func inserisciSnippet(_ snippet: Snippet) {
        fineSessione()
        inserisci(snippet, al: selectedRange())
    }

    /// Piccola animazione: il codice appena inserito si accende di blu e si spegne.
    private func lampeggia(_ r: NSRange) {
        guard let lm = layoutManager, r.length > 0 else { return }
        let passi = 16
        var i = 0
        Timer.scheduledTimer(withTimeInterval: 1.0 / 45, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let lunghezza = (self.string as NSString).length
            let zona = NSIntersectionRange(r, NSRange(location: 0, length: lunghezza))
            if zona.length > 0 { lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: zona) }
            guard i < passi else { t.invalidate(); return }
            let x = Double(i) / Double(passi)
            let alfa = 0.32 * (1 - x * x)
            if zona.length > 0 {
                lm.addTemporaryAttribute(.backgroundColor, value: Tema.lampo.withAlphaComponent(alfa), forCharacterRange: zona)
            }
            i += 1
        }
    }

    private func vaiA(_ punti: [NSRange]) {
        var punti = punti
        let primo = punti.removeFirst()
        setSelectedRange(primo)
        scrollRangeToVisible(primo)
        if punti.isEmpty { fineSessione() } else { attuale = primo; restanti = punti }
    }

    private func prossimoPunto() {
        guard !restanti.isEmpty else { fineSessione(); return }
        vaiA(restanti)
    }

    // MARK: Invio e graffa chiusa

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let sel = selectedRange()
        let inizioRiga = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
        let prima = ns.substring(with: NSRange(location: inizioRiga, length: sel.location - inizioRiga))
        let rientroRiga = String(prima.prefix { $0 == " " || $0 == "\t" })
        let ultimo = prima.trimmingCharacters(in: .whitespaces).last
        let dopo: unichar = NSMaxRange(sel) < ns.length ? ns.character(at: NSMaxRange(sel)) : 0

        if ultimo == "{" {
            if dopo == 125 /* } */ {
                insertText("\n" + rientroRiga + EditorC.rientro + "\n" + rientroRiga, replacementRange: sel)
                let cursore = sel.location + 1 + (rientroRiga + EditorC.rientro).utf16.count
                setSelectedRange(NSRange(location: cursore, length: 0))
            } else {
                insertText("\n" + rientroRiga + EditorC.rientro, replacementRange: sel)
            }
        } else {
            insertText("\n" + rientroRiga, replacementRange: sel)
        }
    }

    // MARK: Chiusura automatica di ( [ { " ' e /* */

    private static let coppie: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
    private static let chiusure: Set<String> = [")", "]", "}", "\"", "'"]

    private func carattere(_ ns: NSString, _ i: Int) -> String? {
        i >= 0 && i < ns.length ? ns.substring(with: NSRange(location: i, length: 1)) : nil
    }

    /// Gestisce un carattere scritto da tastiera; restituisce true se ci ha pensato lui.
    private func chiusuraAutomatica(_ t: String) -> Bool {
        guard Impostazioni.chiusuraAutomatica else { return false }
        let ns = string as NSString
        let sel = selectedRange()
        let prima = carattere(ns, sel.location - 1)
        let dopo = carattere(ns, NSMaxRange(sel))

        // scrivi la chiusura che c'è già subito dopo: il cursore la scavalca
        if sel.length == 0, EditorC.chiusure.contains(t), dopo == t {
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            return true
        }
        // testo selezionato + ( o " : lo racchiude
        if sel.length > 0, let chiusa = EditorC.coppie[t] {
            let dentro = ns.substring(with: sel)
            super.insertText(t + dentro + chiusa, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + 1, length: (dentro as NSString).length))
            return true
        }
        guard sel.length == 0 else { return false }
        // "/" + "*" → /* | */
        if t == "*", prima == "/" {
            super.insertText("**/", replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            return true
        }
        // apertura: chiude solo se dopo c'è spazio, fine riga o un'altra chiusura
        if let chiusa = EditorC.coppie[t] {
            let liberoDopo = dopo == nil || dopo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || ")]};,".contains(dopo!)
            var ok = liberoDopo
            if t == "\"" || t == "'" {
                // non in mezzo a una parola (es. «l'array») e non dopo una barra (\")
                if let p = prima, p.rangeOfCharacter(from: .alphanumerics) != nil || p == "\\" { ok = false }
            }
            if ok {
                super.insertText(t + chiusa, replacementRange: sel)
                setSelectedRange(NSRange(location: sel.location + 1, length: 0))
                return true
            }
        }
        return false
    }

    /// Cancella dentro una coppia vuota: toglie anche la chiusura. Lo stesso per /* */.
    override func deleteBackward(_ sender: Any?) {
        let sel = selectedRange()
        let ns = string as NSString
        if Impostazioni.chiusuraAutomatica, sel.length == 0, sel.location > 0 {
            let p = carattere(ns, sel.location - 1), d = carattere(ns, sel.location)
            if let p = p, let d = d, EditorC.coppie[p] == d {
                insertText("", replacementRange: NSRange(location: sel.location - 1, length: 2))
                return
            }
            if p == "*", carattere(ns, sel.location - 2) == "/", d == "*", carattere(ns, sel.location + 1) == "/" {
                insertText("", replacementRange: NSRange(location: sel.location - 1, length: 3))
                return
            }
        }
        super.deleteBackward(sender)
    }

    override func insertText(_ testo: Any, replacementRange r: NSRange) {
        if r.location == NSNotFound, let t = testo as? String, t.count == 1, chiusuraAutomatica(t) { return }
        if let t = testo as? String, t == "}" {
            let sel = r.location == NSNotFound ? selectedRange() : r
            let ns = string as NSString
            let inizioRiga = ns.lineRange(for: NSRange(location: sel.location, length: 0)).location
            let prima = NSRange(location: inizioRiga, length: sel.location - inizioRiga)
            let spazi = ns.substring(with: prima)
            if sel.length == 0, spazi.count >= 4, spazi.allSatisfy({ $0 == " " }) {
                super.insertText(String(spazi.dropLast(4)) + "}", replacementRange: prima)
                return
            }
        }
        super.insertText(testo, replacementRange: r)
    }

    // MARK: Rientro e commenti su più righe

    private func cambiaRighe(_ trasforma: ([String]) -> [String]) {
        let ns = string as NSString
        let righe = ns.lineRange(for: selectedRange())
        var testo = ns.substring(with: righe)
        var finale = ""
        if testo.hasSuffix("\n") { testo.removeLast(); finale = "\n" }
        let nuovo = trasforma(testo.components(separatedBy: "\n")).joined(separator: "\n") + finale
        insertText(nuovo, replacementRange: righe)
        setSelectedRange(NSRange(location: righe.location, length: (nuovo as NSString).length - finale.utf16.count))
    }

    private func spostaRighe(avanti: Bool) {
        cambiaRighe { righe in
            righe.map { riga in
                if avanti { return riga.isEmpty ? riga : EditorC.rientro + riga }
                if riga.hasPrefix("\t") { return String(riga.dropFirst()) }
                return String(riga.dropFirst(min(4, riga.prefix { $0 == " " }.count)))
            }
        }
    }

    @objc func commentaRighe(_ sender: Any?) {
        fineSessione()
        cambiaRighe { righe in
            let piene = righe.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let commentate = !piene.isEmpty && piene.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            let minimo = piene.map { $0.prefix { $0 == " " || $0 == "\t" }.count }.min() ?? 0
            return righe.map { riga in
                if riga.trimmingCharacters(in: .whitespaces).isEmpty { return riga }
                if commentate, let r = riga.range(of: "//") {
                    var fine = r.upperBound
                    if fine < riga.endIndex, riga[fine] == " " { fine = riga.index(after: fine) }
                    return String(riga[..<r.lowerBound]) + String(riga[fine...])
                }
                let i = riga.index(riga.startIndex, offsetBy: minimo)
                return String(riga[..<i]) + "// " + String(riga[i...])
            }
        }
    }
}

// MARK: - Numeri di riga

final class NumeriRiga: NSRulerView {
    weak var editor: NSTextView?
    /// riga → true se errore, false se avviso
    var segni: [Int: Bool] = [:] { didSet { needsDisplay = true } }

    init(scrollView: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = editor
        ruleThickness = 40
    }

    required init(coder: NSCoder) { fatalError("non usato") }

    private var fontNumeri: NSFont {
        Tema.mono(max(9, Impostazioni.dimensione - 1))
    }

    func aggiorna() {
        guard let ed = editor else { return }
        var righe = 1
        for u in ed.string.utf16 where u == 10 { righe += 1 }
        let cifra = ("8" as NSString).size(withAttributes: [.font: fontNumeri]).width
        let larghezza = ceil(CGFloat(max(2, String(righe).count)) * cifra + 22)
        if larghezza != ruleThickness { ruleThickness = larghezza }
        needsDisplay = true
    }

    private func numeroRiga(_ ns: NSString, _ posizione: Int) -> Int {
        var n = 1
        var i = 0
        let fine = min(posizione, ns.length)
        while i < fine {
            if ns.character(at: i) == 10 { n += 1 }
            i += 1
        }
        return n
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let ed = editor, let lm = ed.layoutManager, let tc = ed.textContainer else { return }
        Tema.editor.setFill()
        bounds.fill()

        let ns = ed.string as NSString
        let origine = ed.textContainerOrigin
        let glifi = lm.glyphRange(forBoundingRect: ed.visibleRect, in: tc)
        let caratteri = lm.characterRange(forGlyphRange: glifi, actualGlyphRange: nil)
        let rigaCursore = numeroRiga(ns, ed.selectedRange().location)

        func disegna(_ n: Int, _ frammento: NSRect) {
            let r = convert(NSRect(x: 0, y: frammento.minY + origine.y, width: 1, height: frammento.height), from: ed)
            var colore = n == rigaCursore ? Tema.numeroCorrente : Tema.numeriRiga
            if let errore = segni[n] {
                colore = errore ? Tema.errore : Tema.avviso
                colore.withAlphaComponent(0.15).setFill()
                NSRect(x: 0, y: r.minY, width: bounds.width - 1, height: r.height).fill()
            }
            let attr: [NSAttributedString.Key: Any] = [.font: fontNumeri, .foregroundColor: colore]
            let testo = "\(n)" as NSString
            let misura = testo.size(withAttributes: attr)
            testo.draw(at: NSPoint(x: bounds.width - misura.width - 10, y: r.minY + (r.height - misura.height) / 2),
                       withAttributes: attr)
        }

        var indice = ns.lineRange(for: NSRange(location: caratteri.location, length: 0)).location
        var riga = numeroRiga(ns, indice)
        while indice < ns.length, indice <= NSMaxRange(caratteri) {
            let lr = ns.lineRange(for: NSRange(location: indice, length: 0))
            disegna(riga, lm.lineFragmentRect(forGlyphAt: lm.glyphIndexForCharacter(at: indice), effectiveRange: nil))
            riga += 1
            indice = NSMaxRange(lr)
        }
        if indice >= ns.length, ns.length == 0 || ns.character(at: ns.length - 1) == 10 {
            disegna(riga, lm.extraLineFragmentRect)
        }
    }
}
