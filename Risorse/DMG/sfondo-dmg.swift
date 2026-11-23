import AppKit

// Disegna lo sfondo della finestra del DMG: nero, un alone di luce dietro l'icona di IDE C e dietro
// la cartella Applicazioni, stelline ad asterisco sparse e la freccia «trascina qui».
// Le icone le mette il Finder; le loro posizioni sono in dmg.py e devono combaciare con `app` e `dest`.
// Le scritte sotto le icone le fa il Finder: bianche col Mac scuro (si leggono), nere col Mac chiaro.
// Uso: sfondo-dmg <cartella>  → scrive sfondo.png (640×400) e sfondo@2x.png

let L: CGFloat = 640, A: CGFloat = 400
let app = CGPoint(x: 180, y: 205), dest = CGPoint(x: 460, y: 205)   // centri delle icone (dall'alto)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

/// Numeri casuali sempre uguali (le stelline restano ferme da un DMG all'altro).
struct Caso {
    var s: UInt64 = 0x1DEC0DE
    mutating func n() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(s >> 33) / CGFloat(1 << 31)
    }
    mutating func tra(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * n() }
}

/// Asterisco: tre bracci che si incrociano (sei punte), con un filo di luce attorno.
func asterisco(_ c: CGPoint, raggio r: CGFloat, alfa: CGFloat, angolo: CGFloat, cg: CGContext) {
    let p = NSBezierPath()
    for k in 0..<3 {
        let t = angolo + CGFloat(k) * .pi / 3
        p.move(to: CGPoint(x: c.x - r * cos(t), y: c.y - r * sin(t)))
        p.line(to: CGPoint(x: c.x + r * cos(t), y: c.y + r * sin(t)))
    }
    p.lineWidth = max(1, r * 0.32)
    p.lineCapStyle = .round
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: r * 1.6, color: hex(0xCFE0FF, alfa * 0.8).cgColor)
    hex(0xFFFFFF, alfa).setStroke()
    p.stroke()
    cg.restoreGState()
}

func disegna(scala: CGFloat, in url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(L * scala), pixelsHigh: Int(A * scala),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: L, height: A)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    // coordinate come il Finder: origine in alto a sinistra
    cg.translateBy(x: 0, y: A)
    cg.scaleBy(x: 1, y: -1)
    let tutto = CGRect(x: 0, y: 0, width: L, height: A)

    // fondo nero, appena più chiaro al centro
    hex(0x050507).setFill()
    tutto.fill()
    NSGradient(colors: [hex(0x16171C), hex(0x050507)], atLocations: [0, 1], colorSpace: .sRGB)!
        .draw(fromCenter: CGPoint(x: L / 2, y: app.y), radius: 0, toCenter: CGPoint(x: L / 2, y: app.y),
              radius: 380, options: [])

    // aloni di luce dietro le due icone: un cuore bianco caldo dentro un bagliore azzurro largo
    for c in [app, dest] {
        NSGradient(colors: [hex(0x5B8CFF, 0.42), hex(0x3D63D9, 0.17), hex(0x2A3F99, 0)],
                   atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
            .draw(fromCenter: c, radius: 0, toCenter: c, radius: 180, options: [])
        NSGradient(colors: [hex(0xFFFFFF, 0.62), hex(0xE6EEFF, 0.24), hex(0xFFFFFF, 0)],
                   atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
            .draw(fromCenter: c, radius: 0, toCenter: c, radius: 108, options: [])
    }

    // stelline: tante piccole e tenui, qualcuna più grande; mai sopra icone, scritte o titolo
    var caso = Caso()
    var messe: [CGPoint] = []
    func libero(_ p: CGPoint, _ r: CGFloat) -> Bool {
        if p.y < 105 && abs(p.x - L / 2) < 200 { return false }                 // titolo
        for c in [app, dest] where abs(p.x - c.x) < 92 && p.y > c.y - 82 && p.y < c.y + 108 { return false }
        if p.x > 255 && p.x < 385 && abs(p.y - 185) < 40 { return false }        // freccia
        return !messe.contains { hypot($0.x - p.x, $0.y - p.y) < r + 22 }
    }
    var tentativi = 0
    while messe.count < 46 && tentativi < 4000 {
        tentativi += 1
        let p = CGPoint(x: caso.tra(14, L - 14), y: caso.tra(14, A - 14))
        let grande = messe.count < 7
        let r = grande ? caso.tra(5, 7.5) : caso.tra(1.8, 3.6)
        guard libero(p, r) else { continue }
        messe.append(p)
        asterisco(p, raggio: r, alfa: grande ? caso.tra(0.75, 0.95) : caso.tra(0.25, 0.6),
                  angolo: caso.tra(0, .pi / 3), cg: cg)
    }
    // puntini lontani
    for _ in 0..<70 {
        let p = CGPoint(x: caso.tra(0, L), y: caso.tra(0, A))
        guard libero(p, 0) else { continue }
        hex(0xFFFFFF, caso.tra(0.12, 0.4)).setFill()
        let d = caso.tra(0.8, 1.6)
        NSBezierPath(ovalIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)).fill()
    }

    // freccia curva tratteggiata
    let da = CGPoint(x: app.x + 82, y: app.y - 4), a = CGPoint(x: dest.x - 86, y: app.y - 4)
    let ctrl = CGPoint(x: (da.x + a.x) / 2, y: app.y - 46)
    let curva = NSBezierPath()
    curva.move(to: da)
    curva.curve(to: a, controlPoint1: ctrl, controlPoint2: ctrl)
    curva.lineWidth = 4
    curva.lineCapStyle = .round
    curva.setLineDash([0.1, 11], count: 2, phase: 0)
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 8, color: hex(0x8FB0FF, 0.6).cgColor)
    hex(0xFFFFFF, 0.92).setStroke()
    curva.stroke()
    let ang = atan2(a.y - ctrl.y, a.x - ctrl.x)
    let punta = NSBezierPath()
    for d in [ang + .pi * 0.78, ang - .pi * 0.78] {
        punta.move(to: CGPoint(x: a.x + 15 * cos(d), y: a.y + 15 * sin(d)))
        punta.line(to: a)
    }
    punta.lineWidth = 4
    punta.lineCapStyle = .round
    punta.lineJoinStyle = .round
    punta.stroke()
    cg.restoreGState()

    // titolo
    NSGraphicsContext.saveGraphicsState()
    let flip = NSAffineTransform()   // il testo va disegnato dritto
    flip.translateX(by: 0, yBy: A)
    flip.scaleX(by: 1, yBy: -1)
    flip.concat()
    let centro = NSMutableParagraphStyle()
    centro.alignment = .center
    let titolo = NSAttributedString(string: "Trascina IDE C in Applicazioni", attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.white,
        .paragraphStyle: centro])
    titolo.draw(in: CGRect(x: 0, y: A - 66, width: L, height: 28))
    let sotto = NSAttributedString(string: "poi aprila dal Launchpad o con Spotlight", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular), .foregroundColor: hex(0xFFFFFF, 0.55),
        .paragraphStyle: centro])
    sotto.draw(in: CGRect(x: 0, y: A - 90, width: L, height: 20))
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let cartella = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
disegna(scala: 1, in: cartella.appendingPathComponent("sfondo.png"))
disegna(scala: 2, in: cartella.appendingPathComponent("sfondo@2x.png"))
