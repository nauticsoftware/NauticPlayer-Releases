#!/bin/bash
# =============================================================================
# sign_and_publish.sh — NauticPlayer Release Helper
# =============================================================================
# USO:
#   1. En Xcode: Product → Archive → Distribute App → Direct Distribution
#      Guarda el DMG notarizado como NauticPlayer-X.Y.dmg en esta carpeta.
#
#   2. Ejecuta este script:
#      ./sign_and_publish.sh NauticPlayer-1.0.dmg 1.0 1
#
#   3. El script:
#      a) Firma el DMG con tu clave EdDSA de Sparkle (en tu Keychain)
#      b) Actualiza el appcast.xml con la firma, tamaño y versión correctos
#      c) Hace commit + push automáticamente
#
# ARGUMENTOS:
#   $1 = nombre del archivo DMG (ej: NauticPlayer-1.0.dmg)
#   $2 = versión corta (ej: 1.0)
#   $3 = build number (ej: 1)
# =============================================================================

set -e

DMG_FILE="$1"
VERSION="$2"
BUILD="$3"

SIGN_UPDATE="/Users/nauticboy/Library/Developer/Xcode/DerivedData/NauticPlayer-fbucjcoudrybttgqkoruzpcqnjtx/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
APPCAST="appcast.xml"
DOWNLOAD_BASE="https://github.com/nauticsoftware/NauticPlayer-Releases/releases/download"

if [ -z "$DMG_FILE" ] || [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "❌ Uso: ./sign_and_publish.sh <archivo.dmg> <version> <build>"
    echo "   Ejemplo: ./sign_and_publish.sh NauticPlayer-1.0.dmg 1.0 1"
    exit 1
fi

if [ ! -f "$DMG_FILE" ]; then
    echo "❌ Archivo DMG no encontrado: $DMG_FILE"
    exit 1
fi

echo "🔐 Firmando $DMG_FILE con Sparkle EdDSA..."
SIGNATURE=$("$SIGN_UPDATE" "$DMG_FILE" 2>/dev/null | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
FILE_SIZE=$(stat -f%z "$DMG_FILE")
DOWNLOAD_URL="$DOWNLOAD_BASE/v$VERSION/$DMG_FILE"
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

echo "✅ Firma: $SIGNATURE"
echo "📦 Tamaño: $FILE_SIZE bytes"
echo "🔗 URL: $DOWNLOAD_URL"

echo ""
echo "📝 Actualizando $APPCAST..."

cat > "$APPCAST" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>NauticPlayer Releases</title>
        <link>https://github.com/nauticsoftware/NauticPlayer-Releases</link>
        <description>NauticPlayer — Actualizaciones oficiales</description>
        <language>es</language>

        <item>
            <title>NauticPlayer $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.7</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>https://raw.githubusercontent.com/nauticsoftware/NauticPlayer-Releases/main/release-notes/$VERSION.html</sparkle:releaseNotesLink>
            <enclosure
                url="$DOWNLOAD_URL"
                sparkle:edSignature="$SIGNATURE"
                length="$FILE_SIZE"
                type="application/octet-stream"
            />
        </item>

    </channel>
</rss>
EOF

echo "✅ appcast.xml actualizado"
echo ""
echo "📤 Subiendo a GitHub..."
git add appcast.xml release-notes/ "$DMG_FILE" 2>/dev/null || git add appcast.xml release-notes/
git commit -m "release: NauticPlayer v$VERSION (build $BUILD)"
git push origin main
git tag "v$VERSION"
git push origin "v$VERSION"

echo ""
echo "🎉 ¡Listo! Ahora crea el GitHub Release manualmente en:"
echo "   https://github.com/nauticsoftware/NauticPlayer-Releases/releases/new"
echo "   - Tag: v$VERSION"
echo "   - Sube el DMG: $DMG_FILE"
echo "   - Copia las release notes de: release-notes/$VERSION.html"
