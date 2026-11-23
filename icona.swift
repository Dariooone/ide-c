// Disegna l'icona dell'app nello stile delle icone Apple recenti: quadrato «squircle» grigio scuro
// come le icone di sistema (Terminale), bordo di luce come vetro, C bianca al centro.
// Uso: swiftc icona.swift -o /tmp/icona && /tmp/icona <cartella>.iconset
import AppKit

let cartella = URL(fileURLWithPath: CommandLine.arguments[1])

try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)

/// Contorno delle icone macOS: lati dritti e angoli a curvatura continua (non archi di cerchio).
/// Ogni angolo è un quarto di superellisse di lato `raggio`.
/// Misure trovate confrontando il contorno con l'icona del Terminale di macOS (differenza 0,1%).
let RAGGIO: CGFloat = 0.34, ESPONENTE: CGFloat = 2.8
func squircle(_ r: NSRect) -> NSBezierPath {
    let raggio = r.width * RAGGIO
    let p = NSBezierPath()
    let centri = [NSPoint(x: r.maxX - raggio, y: r.maxY - raggio), NSPoint(x: r.minX + raggio, y: r.maxY - raggio),
                  NSPoint(x: r.minX + raggio, y: r.minY + raggio), NSPoint(x: r.maxX - raggio, y: r.minY + raggio)]
    for (k, c) in centri.enumerated() {
        for i in 0...60 {
            let t = (CGFloat(k) + CGFloat(i) / 60) * .pi / 2
            let co = cos(t), si = sin(t)
            let x = c.x + raggio * (co < 0 ? -1 : 1) * pow(abs(co), 2 / ESPONENTE)
            let y = c.y + raggio * (si < 0 ? -1 : 1) * pow(abs(si), 2 / ESPONENTE)
            (k == 0 && i == 0) ? p.move(to: NSPoint(x: x, y: y)) : p.line(to: NSPoint(x: x, y: y))
        }
    }
    p.close()
    return p
}

func colore(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func disegna(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let s = CGFloat(px) / 1024

    // griglia delle icone macOS: 824×824 al centro di 1024
    let corpo = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let forma = squircle(corpo)

    // ombra sotto l'icona
    NSGraphicsContext.saveGraphicsState()
    let ombra = NSShadow()
    ombra.shadowColor = NSColor(white: 0, alpha: 0.45)
    ombra.shadowBlurRadius = 28 * s
    ombra.shadowOffset = NSSize(width: 0, height: -12 * s)
    ombra.set()
    colore(0x131314).setFill()
    forma.fill()
    NSGraphicsContext.restoreGraphicsState()

    // corpo: lo stesso grigio scuro delle icone di sistema (misurato sul Terminale di macOS),
    // più chiaro in alto e mai nero
    NSGraphicsContext.saveGraphicsState()
    forma.addClip()
    NSGradient(colors: [colore(0x3D3D3E), colore(0x2A292A), colore(0x1D1D1E), colore(0x161617), colore(0x131314),
                        colore(0x181818)],
               atLocations: [0, 0.10, 0.25, 0.50, 0.80, 1], colorSpace: .sRGB)!.draw(in: corpo, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // bordo di luce come il vetro di macOS: chiaro in alto, più tenue in basso, quasi assente ai lati
    NSGraphicsContext.saveGraphicsState()
    let contorno = NSBezierPath()
    contorno.append(squircle(corpo))
    contorno.append(squircle(corpo.insetBy(dx: 5 * s, dy: 5 * s)).reversed)
    contorno.addClip()
    NSGradient(colors: [NSColor(white: 0.75, alpha: 1), NSColor(white: 0.30, alpha: 1), NSColor(white: 0.10, alpha: 1),
                        NSColor(white: 0.09, alpha: 1), NSColor(white: 0.22, alpha: 1), NSColor(white: 0.50, alpha: 1)],
               atLocations: [0, 0.05, 0.16, 0.84, 0.95, 1], colorSpace: .sRGB)!.draw(in: corpo, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // la C bianca, centrata sul disegno della lettera (non sulla riga del testo)
    var font = NSFont.systemFont(ofSize: 560 * s, weight: .semibold)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: 560 * s) { font = f }
    let lettera = NSAttributedString(string: "C", attributes: [.font: font, .foregroundColor: NSColor.white])
    let riga = CTLineCreateWithAttributedString(lettera)
    let inchiostro = CTLineGetBoundsWithOptions(riga, .useGlyphPathBounds)
    let ctx = NSGraphicsContext.current!.cgContext
    NSGraphicsContext.saveGraphicsState()
    let ombraC = NSShadow()
    ombraC.shadowColor = NSColor(white: 0, alpha: 0.55)
    ombraC.shadowBlurRadius = 24 * s
    ombraC.shadowOffset = NSSize(width: 0, height: -10 * s)
    ombraC.set()
    ctx.textPosition = CGPoint(x: corpo.midX - inchiostro.midX, y: corpo.midY - inchiostro.midY)
    CTLineDraw(riga, ctx)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (nome, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try disegna(px).write(to: cartella.appendingPathComponent("icon_\(nome).png"))
}
