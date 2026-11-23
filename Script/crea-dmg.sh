#!/bin/zsh
# Costruisce l'app (Apple Silicon + Intel) e ne fa il DMG da installare: finestra nera con stelline,
# l'icona di IDE C, una freccia e la cartella Applicazioni (sfondo: Risorse/DMG/sfondo-dmg.swift,
# disposizione: Risorse/DMG/dmg.py).
# Il DMG si chiama sempre IDE-C.dmg, così il link «Scarica» del README punta sempre all'ultima versione.
# Finisce in ~/Documents/Progetti/ (fuori dal vault: è un file generato).
# Uso: Script/crea-dmg.sh            → solo il DMG
#      Script/crea-dmg.sh --carica   → anche la release su GitHub: versione da Risorse/Info.plist,
#                                      note dalla sezione di quella versione in CHANGELOG.md
set -e
RADICE=${0:A:h:h}
"$RADICE/Script/compila.sh" --universale

VERSIONE=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$RADICE/Risorse/Info.plist")
USCITA="$HOME/Documents/Progetti"
DMG="$USCITA/IDE-C.dmg"
STRUMENTI="$HOME/Library/Caches/IDE C/strumenti"   # dmgbuild, installato qui la prima volta
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [[ ! -x "$STRUMENTI/bin/dmgbuild" ]]; then
  echo "Installo dmgbuild (solo la prima volta)…"
  python3 -m venv "$STRUMENTI"
  "$STRUMENTI/bin/pip" install -q dmgbuild
fi

echo "Disegno lo sfondo del DMG…"
cp "$RADICE/Risorse/DMG/sfondo-dmg.swift" "$RADICE/Risorse/DMG/dmg.py" "$TMP/"
swiftc -swift-version 5 "$TMP/sfondo-dmg.swift" -o "$TMP/sfondo" 2>/dev/null
"$TMP/sfondo" "$TMP"
tiffutil -cathidpicheck "$TMP/sfondo.png" "$TMP/sfondo@2x.png" -out "$TMP/sfondo.tiff" >/dev/null 2>&1

echo "Creo il DMG…"
mkdir -p "$USCITA"
rm -f "$DMG"
# hdiutil a volte non riesce a smontare il disco di lavoro («occupato»): si riprova fino a 3 volte
for prova in 1 2 3; do
  "$STRUMENTI/bin/dmgbuild" -s "$TMP/dmg.py" -D app="$HOME/Applications/IDE C.app" -D sfondo="$TMP/sfondo.tiff" \
    "IDE C" "$DMG" >"$TMP/dmgbuild.log" 2>&1 || true
  [[ -f "$DMG" ]] && break
  echo "Il DMG non si è creato (tentativo $prova), riprovo…"
  sleep 3
done
if [[ ! -f "$DMG" ]]; then
  grep -v deprecated "$TMP/dmgbuild.log" >&2
  echo "Errore: il DMG non è stato creato." >&2
  exit 1
fi
echo "Fatto: $DMG  (versione $VERSIONE)"

[[ "$1" == "--carica" ]] || exit 0

# note della release: la sezione «## <versione>» del CHANGELOG + come si installa
NOTE="$TMP/note.md"
awk -v v="$VERSIONE" '/^## /{dentro = ($2 == v)} dentro && !/^## /' "$RADICE/CHANGELOG.md" > "$NOTE"
if [[ ! -s "$NOTE" ]]; then
  echo "Errore: in CHANGELOG.md manca la sezione «## $VERSIONE». Scrivila e riprova." >&2
  exit 1
fi
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
cat >> "$NOTE" <<EOF

### Installazione
1. Scarica **IDE-C.dmg** qui sotto e aprilo.
2. Trascina **IDE C** nella cartella **Applicazioni**.
3. Al primo avvio macOS la blocca perché non viene dall'App Store: apri **Impostazioni di Sistema → Privacy e sicurezza** e premi **Apri comunque**.

Serve macOS 13 o successivo (Apple Silicon o Intel) e il compilatore di Apple: se manca, al primo «Compila» macOS propone di installarlo.

<sub>SHA-256 di IDE-C.dmg: \`$SHA\`</sub>
EOF

cd "$RADICE"
export GIT_DIR="$HOME/Documents/Progetti/ide-c.git"
if gh release view "v$VERSIONE" >/dev/null 2>&1; then
  gh release upload "v$VERSIONE" "$DMG" --clobber
  gh release edit "v$VERSIONE" --title "IDE C $VERSIONE" --notes-file "$NOTE" >/dev/null
else
  gh release create "v$VERSIONE" "$DMG" --title "IDE C $VERSIONE" --notes-file "$NOTE" --latest
fi
echo "Release v$VERSIONE aggiornata su GitHub."
