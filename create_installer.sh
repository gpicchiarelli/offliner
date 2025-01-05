#!/bin/bash

# Verifica se pp è installato
if ! command -v pp &> /dev/null; then
  echo "pp non è installato. Installalo prima di eseguire questo script."
  exit 1
fi

# Definisce i nomi dei file e delle directory
SOURCE_SCRIPT="offliner.pl"
LICENSE_FILE="LICENSE"
APP_NAME="offliner"
BUILD_DIR="build"
INSTALL_LOCATION="/usr/local/$APP_NAME"
PACKAGE_PATH="$BUILD_DIR/$APP_NAME.pkg"
DISTRIBUTION_FILE="$BUILD_DIR/Distribution"
POSTINSTALL_SCRIPT="postinstall"

# Crea una directory temporanea per il build
mkdir -p "$BUILD_DIR"

# Compila lo script Perl in un eseguibile con pp
pp -o "$BUILD_DIR/$APP_NAME" "$SOURCE_SCRIPT"

# Copia il file di licenza nella directory di build
cp "$LICENSE_FILE" "$BUILD_DIR/"

# Crea il file Distribution
cat << EOF > "$DISTRIBUTION_FILE"
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>$APP_NAME</title>
  <options customize="never" allow-external-scripts="no"/>
  <domains enable_localSystem="true"/>
  <license file="$LICENSE_FILE"/>
  <choices-outline>
    <line choice="default">
      <line choice="app"/>
    </line>
  </choices-outline>
  <choice id="default"/>
  <choice id="app" title="$APP_NAME" description="Installazione di $APP_NAME">
    <pkg-ref id="com.offlinerteam.offlinerapp"/>
  </choice>
  <pkg-ref id="com.offlinerteam.offlinerapp" version="1.0" installKBytes="0" auth="Root">file:./$APP_NAME.pkg</pkg-ref>
</installer-gui-script>
EOF

# Crea il file di postinstallazione
cat << EOF > "$POSTINSTALL_SCRIPT"
#!/bin/bash
ln -sf "$INSTALL_LOCATION/$APP_NAME" /usr/bin/$APP_NAME
EOF

chmod +x "$POSTINSTALL_SCRIPT"

# Crea il pacchetto dell'applicazione
pkgbuild --identifier "com.offliner.offlinerapp" \
         --version "1.0" \
         --install-location "$INSTALL_LOCATION" \
         --root "$BUILD_DIR" \
         --scripts . \
         "$PACKAGE_PATH"

# Crea l'installer completo con la licenza
productbuild --distribution "$DISTRIBUTION_FILE" \
             --package-path "$BUILD_DIR" \
             "$APP_NAME-installer.pkg"

# Pulisce la directory di build
rm -rf "$BUILD_DIR"

echo "Installer creato con successo: $APP_NAME-installer.pkg"
