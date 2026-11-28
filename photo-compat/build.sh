#!/usr/bin/env bash
# Build and sign the companion APK locally. Nothing is installed on the device.
set -euo pipefail
if (( $# != 2 )); then
    echo 'Usage: ANDROID_HOME=... bash build.sh XPOSED_API_82.jar OUTPUT_DIR' >&2
    exit 2
fi
: "${ANDROID_HOME:?Android SDK with platforms/android-36 and build-tools/35.0.0 required}"
api=$(realpath "$1")
src=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p -- "$2"
out=$(cd -- "$2" && pwd)
jar36="$ANDROID_HOME/platforms/android-36/android.jar"
tools="$ANDROID_HOME/build-tools/35.0.0"
mkdir -p "$out/classes" "$out/dex"
javac --release 8 -cp "$jar36:$api" -d "$out/classes" "$src/PhotoCompat.java" "$src/PhotoMetadata.java" "$src/InfoActivity.java"
jar cf "$out/module.jar" -C "$out/classes" local/pjd110/photocompat
"$tools/d8" --min-api 34 --lib "$jar36" --classpath "$api" --output "$out/dex" "$out/module.jar"
"$tools/aapt" package -f -M "$src/AndroidManifest.xml" -I "$jar36" -A "$src/assets" -F "$out/base.apk"
(cd "$out/dex" && "$tools/aapt" add ../base.apk classes.dex)
"$tools/zipalign" -f 4 "$out/base.apk" "$out/aligned.apk"
keystore=${PHOTO_COMPAT_KEYSTORE:-"$out/photo-compat.jks"}
if [[ ! -e "$keystore" ]]; then
    (umask 077; keytool -genkeypair -keystore "$keystore" -storepass android -keypass android \
        -alias photo-compat -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=PJD110 Photo Compatibility')
fi
"$tools/apksigner" sign --ks "$keystore" --ks-pass pass:android \
    --out "$out/PJD110-PhotoCompat.apk" "$out/aligned.apk"
"$tools/apksigner" verify "$out/PJD110-PhotoCompat.apk"
