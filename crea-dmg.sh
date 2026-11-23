#!/bin/zsh
# Costruisce l'app e ne fa un DMG da installare (trascina «IDE C» in Applicazioni).
# Il DMG finisce in ~/Documents/Progetti/ (fuori dal vault: è un file generato).
# Uso: ./crea-dmg.sh            → solo il DMG
#      ./crea-dmg.sh --carica   → anche la release su GitHub (versione presa da Info.plist)
set -e
QUI=${0:A:h}
"$QUI/compila.sh"

VERSIONE=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$QUI/Info.plist")
USCITA="$HOME/Documents/Progetti"
DMG="$USCITA/IDE-C-$VERSIONE.dmg"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Creo il DMG…"
mkdir -p "$TMP/IDE C" "$USCITA"
ditto "$HOME/Applications/IDE C.app" "$TMP/IDE C/IDE C.app"
ln -s /Applications "$TMP/IDE C/Applicazioni"
rm -f "$DMG"
hdiutil create -volname "IDE C" -srcfolder "$TMP/IDE C" -fs HFS+ -format UDZO -ov "$DMG" 2>&1 | grep -v deprecated || true
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
