import Foundation

// Scorciatoie: scrivi la parola e premi Tab.
// Nel testo:  ${1:testo}  primo punto da riempire (Tab passa al successivo)
//             ${2}        punto vuoto
//             $0          dove finisce il cursore
// Le righe dopo la prima prendono da sole il rientro della riga dove sei.
// Per aggiungerne una: copia una riga, cambia parola, descrizione e testo, poi ./compila.sh

struct Snippet {
    let parola: String
    let descrizione: String
    let testo: String
}

struct Sezione {
    let nome: String
    let simbolo: String      // icona SF Symbols nella legenda
    let snippet: [Snippet]
}

private func s(_ parola: String, _ descrizione: String, _ testo: String) -> Snippet {
    Snippet(parola: parola, descrizione: descrizione, testo: testo)
}

let SEZIONI: [Sezione] = [
    Sezione(nome: "Inizio del programma", simbolo: "doc.badge.plus", snippet: [
        s("main", "Programma completo con stdio e stdlib", #"""
            #include <stdio.h>
            #include <stdlib.h>

            int main() {
                $0
                return 0;
            }
            """#),
        s("mainb", "Solo la funzione main", #"""
            int main() {
                $0
                return 0;
            }
            """#),
        s("maina", "main con argc e argv", #"""
            #include <stdio.h>
            #include <stdlib.h>

            int main(int argc, char *argv[]) {
                $0
                return 0;
            }
            """#),
        s("incs", "Le librerie di tutti i giorni", #"""
            #include <stdio.h>
            #include <stdlib.h>
            #include <string.h>
            #include <math.h>
            #include <ctype.h>
            $0
            """#),
        s("inc", "#include <…>", #"#include <${1:stdio.h}>$0"#),
        s("incl", "#include \"…\" (file tuo)", #"#include "${1:file.h}"$0"#),
        s("def", "#define", #"#define ${1:N} ${2:100}$0"#),
    ]),

    Sezione(nome: "Stampare: printf", simbolo: "text.bubble", snippet: [
        s("pf", "Testo", #"printf("${1:testo}\n");$0"#),
        s("pfv", "Formato a scelta e una variabile", #"printf("${1:%d}\n", ${2:x});$0"#),
        s("pfd", "Un int", #"printf("%d\n", ${1:x});$0"#),
        s("pfld", "Un long", #"printf("%ld\n", ${1:x});$0"#),
        s("pfu", "Un unsigned", #"printf("%u\n", ${1:x});$0"#),
        s("pff", "Un float o double", #"printf("%f\n", ${1:x});$0"#),
        s("pf2", "Un numero con 2 decimali", #"printf("%.2f\n", ${1:x});$0"#),
        s("pfe", "Un numero in notazione scientifica", #"printf("%e\n", ${1:x});$0"#),
        s("pfc", "Un char", #"printf("%c\n", ${1:c});$0"#),
        s("pfs", "Una stringa", #"printf("%s\n", ${1:s});$0"#),
        s("pfp", "Un indirizzo (puntatore)", #"printf("%p\n", (void *) ${1:p});$0"#),
        s("pfx", "Un int in esadecimale", #"printf("%x\n", ${1:x});$0"#),
        s("pfr", "Etichetta e risultato", #"printf("${1:Risultato}: %d\n", ${2:x});$0"#),
        s("pf2v", "Due variabili con il nome", #"printf("${1:a} = %d, ${2:b} = %d\n", ${3:a}, ${4:b});$0"#),
        s("pfa", "Tutto un array su una riga", #"""
            for (int i = 0; i < ${1:n}; i++) {
                printf("%d ", ${2:v}[i]);
            }
            printf("\n");$0
            """#),
        s("pfm", "Una matrice, riga per riga", #"""
            for (int i = 0; i < ${1:R}; i++) {
                for (int j = 0; j < ${2:C}; j++) {
                    printf("%4d", ${3:m}[i][j]);
                }
                printf("\n");
            }$0
            """#),
        s("puts", "puts (va a capo da solo)", #"puts("${1:testo}");$0"#),
        s("nl", "Vai a capo", #"printf("\n");$0"#),
    ]),

    Sezione(nome: "Leggere: scanf", simbolo: "keyboard", snippet: [
        s("sf", "Formato a scelta", #"scanf("${1:%d}", &${2:x});$0"#),
        s("sfd", "Un int", #"scanf("%d", &${1:x});$0"#),
        s("sfld", "Un long", #"scanf("%ld", &${1:x});$0"#),
        s("sff", "Un float", #"scanf("%f", &${1:x});$0"#),
        s("sflf", "Un double", #"scanf("%lf", &${1:x});$0"#),
        s("sfc", "Un char (salta spazi e a capo)", #"scanf(" %c", &${1:c});$0"#),
        s("sfs", "Una parola (fino allo spazio)", #"scanf("%s", ${1:s});$0"#),
        s("sfl", "Una riga intera, con gli spazi", #"scanf(" %[^\n]", ${1:s});$0"#),
        s("sf2", "Due int sulla stessa riga", #"scanf("%d %d", &${1:a}, &${2:b});$0"#),
        s("sfa", "Tutto un array", #"""
            for (int i = 0; i < ${1:n}; i++) {
                scanf("%d", &${2:v}[i]);
            }$0
            """#),
        s("sfm", "Una matrice", #"""
            for (int i = 0; i < ${1:R}; i++) {
                for (int j = 0; j < ${2:C}; j++) {
                    scanf("%d", &${3:m}[i][j]);
                }
            }$0
            """#),
        s("sfeof", "Leggi numeri finché finiscono (EOF)", #"""
            while (scanf("%d", &${1:x}) == 1) {
                $0
            }
            """#),
        s("ask", "Chiedi un int e leggilo", #"""
            printf("${1:Inserisci un numero}: ");
            scanf("%d", &${2:x});$0
            """#),
        s("askf", "Chiedi un double e leggilo", #"""
            printf("${1:Inserisci un numero}: ");
            scanf("%lf", &${2:x});$0
            """#),
        s("asks", "Chiedi una parola e leggila", #"""
            printf("${1:Inserisci una parola}: ");
            scanf("%s", ${2:s});$0
            """#),
        s("askv", "Chiedi finché il valore va bene", #"""
            do {
                printf("${1:Inserisci un numero positivo}: ");
                scanf("%d", &${2:x});
            } while (${3:x <= 0});$0
            """#),
        s("fgets", "Una riga intera con fgets", #"fgets(${1:riga}, ${2:100}, stdin);$0"#),
    ]),

    Sezione(nome: "Variabili e array", simbolo: "square.stack.3d.up", snippet: [
        s("str", "Stringa (array di char)", #"char ${1:s}[${2:100}];$0"#),
        s("arr", "Array di int", #"int ${1:v}[${2:N}];$0"#),
        s("mat", "Matrice di int", #"int ${1:m}[${2:R}][${3:C}];$0"#),
    ]),

    Sezione(nome: "Controllo del flusso", simbolo: "arrow.triangle.branch", snippet: [
        s("if", "if", #"""
            if (${1:condizione}) {
                $0
            }
            """#),
        s("ife", "if … else", #"""
            if (${1:condizione}) {
                ${2}
            } else {
                $0
            }
            """#),
        s("elif", "else if", #"""
            else if (${1:condizione}) {
                $0
            }
            """#),
        s("else", "else", #"""
            else {
                $0
            }
            """#),
        s("for", "for con i", #"""
            for (int i = 0; i < ${1:n}; i++) {
                $0
            }
            """#),
        s("forj", "for con j", #"""
            for (int j = 0; j < ${1:n}; j++) {
                $0
            }
            """#),
        s("fork", "for con k", #"""
            for (int k = 0; k < ${1:n}; k++) {
                $0
            }
            """#),
        s("forr", "for all'indietro", #"""
            for (int i = ${1:n} - 1; i >= 0; i--) {
                $0
            }
            """#),
        s("format", "Doppio for per le matrici", #"""
            for (int i = 0; i < ${1:R}; i++) {
                for (int j = 0; j < ${2:C}; j++) {
                    $0
                }
            }
            """#),
        s("while", "while", #"""
            while (${1:condizione}) {
                $0
            }
            """#),
        s("do", "do … while", #"""
            do {
                $0
            } while (${1:condizione});
            """#),
        s("sw", "switch", #"""
            switch (${1:x}) {
                case ${2:1}:
                    $0
                    break;
                default:
                    break;
            }
            """#),
        s("case", "case", #"""
            case ${1:1}:
                $0
                break;
            """#),
    ]),

    Sezione(nome: "Funzioni e tipi", simbolo: "function", snippet: [
        s("fn", "Funzione", #"""
            ${1:int} ${2:nome}(${3:int x}) {
                $0
            }
            """#),
        s("void", "Funzione void", #"""
            void ${1:nome}(${2}) {
                $0
            }
            """#),
        s("proto", "Prototipo di funzione", #"${1:int} ${2:nome}(${3:int x});$0"#),
        s("ret", "return", #"return ${1:0};$0"#),
        s("st", "struct", #"""
            struct ${1:nome} {
                ${2:int x;}
            };$0
            """#),
        s("ts", "typedef struct", #"""
            typedef struct {
                ${1:int x;}
            } ${2:Nome};$0
            """#),
    ]),

    Sezione(nome: "Memoria e file", simbolo: "externaldrive", snippet: [
        s("mal", "malloc con controllo", #"""
            ${1:int} *${2:p} = malloc(${3:n} * sizeof(${4:int}));
            if (${5:p} == NULL) {
                printf("Memoria esaurita\n");
                return 1;
            }$0
            """#),
        s("fopen", "Apri un file con controllo", #"""
            FILE *fp = fopen("${1:file.txt}", "${2:r}");
            if (fp == NULL) {
                printf("Errore nell'apertura del file\n");
                return 1;
            }
            $0
            fclose(fp);
            """#),
        s("fpf", "fprintf su file", #"fprintf(${1:fp}, "${2:%d}\n", ${3:x});$0"#),
        s("fsf", "fscanf da file", #"fscanf(${1:fp}, "${2:%d}", &${3:x});$0"#),
    ]),

    Sezione(nome: "Varie", simbolo: "ellipsis.curlybraces", snippet: [
        s("cm", "Commento /* … */", #"/* ${1} */$0"#),
    ]),
]

let SNIPPET: [Snippet] = SEZIONI.flatMap { $0.snippet }

/// Testo pronto da inserire e posizioni (UTF-16) dei punti da riempire; l'ultimo è $0.
struct Espansione {
    let testo: String
    let punti: [NSRange]
}

func espandi(_ modello: String, rientro: String) -> Espansione {
    var uscita = ""
    var lunghezza = 0
    var punti: [(Int, NSRange)] = []
    let c = Array(modello)
    var i = 0

    func aggiungi(_ t: String) {
        uscita += t
        lunghezza += t.utf16.count
    }

    while i < c.count {
        if c[i] == "$", i + 1 < c.count {
            if c[i + 1] == "{", let fine = c[(i + 2)...].firstIndex(of: "}") {
                let dentro = String(c[(i + 2)..<fine])
                let parti = dentro.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                if let n = Int(parti[0]) {
                    let inizio = lunghezza
                    aggiungi(parti.count > 1 ? String(parti[1]) : "")
                    punti.append((n, NSRange(location: inizio, length: lunghezza - inizio)))
                    i = fine + 1
                    continue
                }
            } else if let n = c[i + 1].wholeNumberValue {
                punti.append((n, NSRange(location: lunghezza, length: 0)))
                i += 2
                continue
            }
        }
        aggiungi(c[i] == "\n" ? "\n" + rientro : String(c[i]))
        i += 1
    }

    var ordinati = punti.filter { $0.0 != 0 }.sorted { $0.0 < $1.0 }.map { $0.1 }
    ordinati.append(punti.first { $0.0 == 0 }?.1 ?? NSRange(location: lunghezza, length: 0))
    return Espansione(testo: uscita, punti: ordinati)
}
