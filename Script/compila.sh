#!/bin/zsh
# Costruisce «IDE C.app» in ~/Applications (fuori dal vault). Serve solo: xcode-select --install
# Uso: Script/compila.sh               → solo per questo Mac (Apple Silicon), più veloce
#      Script/compila.sh --universale  → Apple Silicon + Intel (lo usa crea-dmg.sh per le release)
set -e
RADICE=${0:A:h:h}
APP="$HOME/Applications/IDE C.app"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# copia dei sorgenti: Syncthing a volte li tocca mentre swiftc li legge
mkdir -p "$TMP/src"
cp "$RADICE"/Sorgenti/*.swift "$RADICE/Risorse/icona.swift" "$TMP/src/"

ARCHITETTURE=(arm64)
[[ "$1" == "--universale" ]] && ARCHITETTURE=(arm64 x86_64)
for arch in $ARCHITETTURE; do
  echo "Compilo l'app ($arch)…"
  swiftc -swift-version 5 -O -module-name IDEC -target $arch-apple-macos13.0 \
    "$TMP"/src/[A-Z]*.swift "$TMP/src/main.swift" -o "$TMP/IDEC-$arch" 2>"$TMP/swiftc.log" \
    || { cat "$TMP/swiftc.log" >&2; exit 1; }
done
lipo -create "$TMP"/IDEC-* -output "$TMP/IDEC"

echo "Disegno l'icona…"
swiftc -swift-version 5 "$TMP/src/icona.swift" -o "$TMP/icona"
"$TMP/icona" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$TMP/AppIcon.icns"

echo "Preparo il pacchetto…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/it.lproj"
cp "$TMP/IDEC" "$APP/Contents/MacOS/IDEC"
cp "$RADICE/Risorse/Info.plist" "$APP/Contents/Info.plist"
cp "$TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" 2>/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Fatto: $APP  (se era aperta, chiudila e riaprila)"
