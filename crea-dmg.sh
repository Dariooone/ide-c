#!/bin/zsh
# Costruisce l'app e ne fa un DMG da installare: finestra blu con l'icona di IDE C,
# una freccia e la cartella Applicazioni (sfondo: sfondo-dmg.swift, disposizione: dmg.py).
# Il DMG finisce in ~/Documents/Progetti/ (fuori dal vault: è un file generato).
# Uso: ./crea-dmg.sh            → solo il DMG
#      ./crea-dmg.sh --carica   → anche la release su GitHub (versione presa da Info.plist)
set -e
QUI=${0:A:h}
"$QUI/compila.sh"

VERSIONE=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$QUI/Info.plist")
USCITA="$HOME/Documents/Progetti"
DMG="$USCITA/IDE-C-$VERSIONE.dmg"
STRUMENTI="$HOME/Library/Caches/IDE C/strumenti"   # dmgbuild, installato qui la prima volta
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [[ ! -x "$STRUMENTI/bin/dmgbuild" ]]; then
  echo "Installo dmgbuild (solo la prima volta)…"
  python3 -m venv "$STRUMENTI"
  "$STRUMENTI/bin/pip" install -q dmgbuild
fi

echo "Disegno lo sfondo del DMG…"
cp "$QUI/sfondo-dmg.swift" "$TMP/"
swiftc -swift-version 5 "$TMP/sfondo-dmg.swift" -o "$TMP/sfondo" 2>/dev/null
"$TMP/sfondo" "$TMP"
tiffutil -cathidpicheck "$TMP/sfondo.png" "$TMP/sfondo@2x.png" -out "$TMP/sfondo.tiff" >/dev/null 2>&1

echo "Creo il DMG…"
mkdir -p "$USCITA"
cp "$QUI/dmg.py" "$TMP/"
rm -f "$DMG"
"$STRUMENTI/bin/dmgbuild" -s "$TMP/dmg.py" -D app="$HOME/Applications/IDE C.app" -D sfondo="$TMP/sfondo.tiff" \
  "IDE C" "$DMG" 2>&1 >/dev/null | grep -v deprecated || true   # hdiutil avvisa che è «deprecato»: si ignora
[[ -f "$DMG" ]] || { echo "Errore: il DMG non è stato creato." >&2; exit 1; }
echo "Fatto: $DMG"

if [[ "$1" == "--carica" ]]; then
  cd "$QUI"
  export GIT_DIR="$HOME/Documents/Progetti/ide-c.git"
  if gh release view "v$VERSIONE" >/dev/null 2>&1; then
    gh release upload "v$VERSIONE" "$DMG" --clobber
  else
    gh release create "v$VERSIONE" "$DMG" --title "IDE C $VERSIONE" \
      --notes "Apri il DMG e trascina «IDE C» in Applicazioni. Al primo avvio: Impostazioni di Sistema → Privacy e sicurezza → «Apri comunque» (l'app non è firmata da Apple)."
  fi
  echo "Caricato su GitHub nella release v$VERSIONE."
fi
