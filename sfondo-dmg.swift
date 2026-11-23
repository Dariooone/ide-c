import AppKit

// Disegna lo sfondo della finestra del DMG: blu di IDE C, righe di codice appena visibili,
// un alone sotto le due icone e la freccia «trascina qui».
// Le icone le mette il Finder; le loro posizioni sono in crea-dmg.sh (APP_X, APP_Y, DEST_X).
// Il blu ha una luminosità media apposta: le scritte sotto le icone le fa il Finder,
// bianche se il Mac è scuro e nere se è chiaro, e devono leggersi in tutti e due i casi.
// Uso: sfondo-dmg <cartella>  → scrive sfondo.png (640×400) e sfondo@2x.png

let L: CGFloat = 640, A: CGFloat = 400
let app = CGPoint(x: 180, y: 205), dest = CGPoint(x: 460, y: 205)   // centri delle icone (dall'alto)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
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

    // fondo: blu → indaco, in diagonale
    NSGradient(colors: [hex(0x3E7CF2), hex(0x3A63E4), hex(0x4C55D6)], atLocations: [0, 0.55, 1],
               colorSpace: .sRGB)!.draw(in: NSBezierPath(rect: tutto), angle: -35)
    // luce morbida dall'alto
    NSGradient(colors: [hex(0xFFFFFF, 0.16), hex(0xFFFFFF, 0)], atLocations: [0, 1], colorSpace: .sRGB)!
        .draw(fromCenter: CGPoint(x: L / 2, y: -40), radius: 0, toCenter: CGPoint(x: L / 2, y: -40), radius: 380,
              options: [])

    // righe di codice appena visibili
    let codice = [
        "#include <stdio.h>", "", "int main(void) {", "    int n;", "    printf(\"Quanti numeri? \");",
        "    scanf(\"%d\", &n);", "    for (int i = 0; i < n; i++) {", "        printf(\"%d\\n\", i * i);",
        "    }", "    return 0;", "}",
    ]
    let mono = NSFont(name: "JetBrainsMono-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
    let attrCodice: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: hex(0xFFFFFF, 0.075)]
    NSGraphicsContext.saveGraphicsState()
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    let flip = NSAffineTransform()   // il testo va disegnato dritto
    flip.translateX(by: 0, yBy: A)
    flip.scaleX(by: 1, yBy: -1)
    flip.concat()
    for (i, riga) in (codice + [""] + codice).enumerated() {
        let y = A - 18 - CGFloat(i) * 19
        (riga as NSString).draw(at: CGPoint(x: 26, y: y), withAttributes: attrCodice)
        (riga as NSString).draw(at: CGPoint(x: 360, y: y + 9), withAttributes: attrCodice)
    }
    flip.invert()
    flip.concat()
    // il codice sfuma via dietro le icone e le loro scritte
    cg.setBlendMode(.destinationOut)
    for c in [app, dest] {
        cg.saveGState()
        cg.translateBy(x: c.x, y: c.y + 14)
        cg.scaleBy(x: 1.15, y: 1)
        NSGradient(colors: [hex(0, 1), hex(0, 1), hex(0, 0)], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!
            .draw(fromCenter: .zero, radius: 0, toCenter: .zero, radius: 125, options: [])
        cg.restoreGState()
    }
    cg.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()

    // aloni sotto le icone
    for c in [app, dest] {
        NSGradient(colors: [hex(0xFFFFFF, 0.20), hex(0xFFFFFF, 0.07), hex(0xFFFFFF, 0)],
                   atLocations: [0, 0.6, 1], colorSpace: .sRGB)!
            .draw(fromCenter: c, radius: 0, toCenter: c, radius: 108, options: [])
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
    hex(0xFFFFFF, 0.92).setStroke()
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -1), blur: 6, color: hex(0x1A2A80, 0.35).cgColor)
    curva.stroke()
    // punta: nella direzione della curva all'arrivo
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
    flip.concat()
    let ombra = NSShadow()
    ombra.shadowColor = hex(0x10205A, 0.35)
    ombra.shadowBlurRadius = 6
    ombra.shadowOffset = NSSize(width: 0, height: -1)
    let centro = NSMutableParagraphStyle()
    centro.alignment = .center
    let titolo = NSAttributedString(string: "Trascina IDE C in Applicazioni", attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: NSColor.white,
        .paragraphStyle: centro, .shadow: ombra])
    titolo.draw(in: CGRect(x: 0, y: A - 66, width: L, height: 28))
    let sotto = NSAttributedString(string: "poi aprila dal Launchpad o con Spotlight", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular), .foregroundColor: hex(0xFFFFFF, 0.78),
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
