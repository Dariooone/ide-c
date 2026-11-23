import Foundation
import Darwin

struct ErroreIDE: LocalizedError {
    let messaggio: String
    var errorDescription: String? { messaggio }
}

// MARK: - Compilazione con clang

struct RisultatoCompilazione {
    let ok: Bool
    let uscita: String
    let eseguibile: URL
}

enum Compilatore {
    /// Opzioni passate a clang. -Wall mostra anche gli avvisi.
    /// Opzioni passate a clang, prese dalle Impostazioni (standard del C, avvisi).
    static var opzioni: [String] {
        ["-std=" + Impostazioni.standardC, "-fno-color-diagnostics"]
            + (Impostazioni.avvisi ? ["-Wall"] : [])
            + (Impostazioni.pedantico ? ["-pedantic"] : [])
    }

    /// Compila una copia del testo nella cartella `cache` (fuori dal vault).
    /// `include` è la cartella del file vero, per i #include "…" dei tuoi .h.
    static func compila(testo: String, nome: String, cache: URL, include: URL) -> RisultatoCompilazione {
        let eseguibile = cache.appendingPathComponent((nome as NSString).deletingPathExtension)
        do {
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try testo.write(to: cache.appendingPathComponent(nome), atomically: true, encoding: .utf8)
        } catch {
            return RisultatoCompilazione(ok: false, uscita: "Non riesco a preparare il file: \(error.localizedDescription)",
                                         eseguibile: eseguibile)
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/clang")
        p.arguments = opzioni + ["-I", include.path, nome, "-o", eseguibile.lastPathComponent, "-lm"]
        p.currentDirectoryURL = cache
        let tubo = Pipe()
        p.standardOutput = tubo
        p.standardError = tubo
        do {
            try p.run()
        } catch {
            return RisultatoCompilazione(ok: false,
                uscita: "clang non trovato. Installa gli strumenti da Terminale con:  xcode-select --install",
                eseguibile: eseguibile)
        }
        let dati = tubo.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return RisultatoCompilazione(ok: p.terminationStatus == 0,
                                     uscita: String(decoding: dati, as: UTF8.self), eseguibile: eseguibile)
    }
}

// MARK: - Esecuzione dentro l'app, con un terminale finto (pty) così printf e scanf vanno come nel Terminale

final class Esecuzione {
    private let processo = Process()
    private var master: Int32 = -1
    private var sorgente: DispatchSourceRead?
    private var letturaFinita = false
    private var fine: (Process.TerminationReason, Int32)?
    private var fermato = false

    var suUscita: ((String) -> Void)?
    /// motivo, codice, fermato da te
    var suFine: ((Process.TerminationReason, Int32, Bool) -> Void)?

    var inCorso: Bool { suFine != nil }

    func avvia(_ eseguibile: URL, cartella: URL) throws {
        let m = posix_openpt(O_RDWR | O_NOCTTY)
        guard m >= 0, grantpt(m) == 0, unlockpt(m) == 0, let nome = ptsname(m) else {
            if m >= 0 { close(m) }
            throw ErroreIDE(messaggio: "Non riesco a creare la console del programma.")
        }
        let s = open(nome, O_RDWR | O_NOCTTY)
        guard s >= 0 else {
            close(m)
            throw ErroreIDE(messaggio: "Non riesco ad aprire la console del programma.")
        }
        master = m
        // niente eco: l'input lo scrive la finestra (in verde), e niente «^D» a video
        var impostazioni = termios()
        if tcgetattr(s, &impostazioni) == 0 {
            impostazioni.c_lflag &= ~tcflag_t(ECHO | ECHOCTL)
            tcsetattr(s, TCSANOW, &impostazioni)
        }

        let lato = FileHandle(fileDescriptor: s, closeOnDealloc: true)
        processo.executableURL = eseguibile
        processo.currentDirectoryURL = cartella
        processo.standardInput = lato
        processo.standardOutput = lato
        processo.standardError = lato
        var ambiente = ProcessInfo.processInfo.environment
        ambiente["TERM"] = "dumb"
        processo.environment = ambiente

        let src = DispatchSource.makeReadSource(fileDescriptor: m, queue: .global(qos: .userInitiated))
        sorgente = src
        src.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 8192)
            let n = read(m, &buffer, buffer.count)
            if n <= 0 { src.cancel(); return }
            let testo = String(decoding: buffer[0..<n], as: UTF8.self)
                .replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\u{04}", with: "")
            DispatchQueue.main.async { self?.suUscita?(testo) }
        }
        src.setCancelHandler { [weak self] in
            DispatchQueue.main.async {
                close(m)
                self?.master = -1
                self?.letturaFinita = true
                self?.controlla()
            }
        }
        processo.terminationHandler = { [weak self] p in
            let motivo = p.terminationReason, codice = p.terminationStatus
            DispatchQueue.main.async {
                self?.fine = (motivo, codice)
                self?.controlla()
            }
            // se qualcosa tiene aperta la console, smetti comunque di leggere
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { src.cancel() }
        }

        do {
            try processo.run()
        } catch {
            src.cancel()
            src.resume()
            throw ErroreIDE(messaggio: "Non riesco ad avviare il programma: \(error.localizedDescription)")
        }
        try? lato.close()
        src.resume()
    }

    private func controlla() {
        guard letturaFinita, let f = fine, let fatto = suFine else { return }
        suFine = nil
        fatto(f.0, f.1, fermato)
    }

    func scrivi(_ testo: String) {
        guard master >= 0 else { return }
        let byte = Array(testo.utf8)
        byte.withUnsafeBytes { _ = write(master, $0.baseAddress, $0.count) }
    }

    /// Come Ctrl+D nel Terminale: il programma legge EOF.
    func fineInput() { scrivi("\u{04}") }

    func ferma() {
        guard processo.isRunning else { return }
        fermato = true
        processo.terminate()
        let pid = processo.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [processo] in
            if processo.isRunning { kill(pid, SIGKILL) }
        }
    }
}
