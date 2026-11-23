#!/bin/zsh
# Costruisce «IDE C.app» in ~/Applications (fuori dal vault). Serve solo: xcode-select --install
set -e
QUI=${0:A:h}
APP="$HOME/Applications/IDE C.app"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# copia dei sorgenti: Syncthing a volte li tocca mentre swiftc li legge
mkdir -p "$TMP/src"
cp "$QUI"/Sorgenti/*.swift "$QUI/icona.swift" "$TMP/src/"

echo "Compilo l'app…"
swiftc -swift-version 5 -O -module-name IDEC -target arm64-apple-macos13.0 \
  "$TMP"/src/[A-Z]*.swift "$TMP/src/main.swift" -o "$TMP/IDEC"

echo "Disegno l'icona…"
swiftc -swift-version 5 "$TMP/src/icona.swift" -o "$TMP/icona"
"$TMP/icona" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$TMP/AppIcon.icns"

echo "Preparo il pacchetto…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/it.lproj"
cp "$TMP/IDEC" "$APP/Contents/MacOS/IDEC"
cp "$QUI/Info.plist" "$APP/Contents/Info.plist"
cp "$TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Fatto: $APP  (se era aperta, chiudila e riaprila)"
