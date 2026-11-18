#!/usr/bin/env bash
# Builds the Emta Android app. GitHub runs this for you (see .github/workflows/build.yml).
# To change how the app is built, replace this one file. You never need to edit build.yml again.
set -euo pipefail

echo "== 1. Get the latest Emta web app from the Waqt repo"
rm -rf www
git clone --depth 1 https://github.com/ZalabyaDev/Waqt.git www
rm -rf www/.git
test -f www/index.html

echo "== 2. Install Capacitor and create the Android project"
npm install
rm -rf android
npx cap add android

echo "== 3. Version number (each build gets a higher one, which Google Play needs)"
RUN="${GITHUB_RUN_NUMBER:-1}"
sed -i "s/versionCode 1\$/versionCode ${RUN}/; s/versionName \"1.0\"/versionName \"0.10.${RUN}\"/" android/app/build.gradle
grep -n "versionCode\|versionName" android/app/build.gradle

echo "== 4. Permissions: location (prayer times) and on-time reminders"
M=android/app/src/main/AndroidManifest.xml
add_perm() { grep -q "android.permission.$1\"" "$M" || sed -i "s#</manifest>#    <uses-permission android:name=\"android.permission.$1\" />\n</manifest>#" "$M"; }
add_perm ACCESS_COARSE_LOCATION
add_perm ACCESS_FINE_LOCATION
add_perm SCHEDULE_EXACT_ALARM
cat "$M"

echo "== 5. App icon"
mkdir -p assets
for f in icon-only.png icon-foreground.png icon-background.png; do if [ -f "$f" ]; then mv "$f" assets/; fi; done
npx @capacitor/assets generate --android --iconBackgroundColor '#5C7A5C' --splashBackgroundColor '#FAF8F3'
RES=android/app/src/main/res
node -e "const sharp=require('sharp');const d={mdpi:108,hdpi:162,xhdpi:216,xxhdpi:324,xxxhdpi:432};const jobs=[];for(const [k,v] of Object.entries(d)){for(const n of ['foreground','background']){jobs.push(sharp('assets/icon-'+n+'.png').resize(v,v).png().toFile('$RES/mipmap-'+k+'/ic_launcher_'+n+'.png'))}}Promise.all(jobs).catch(e=>{console.error(e);process.exit(1)})"
for n in ic_launcher ic_launcher_round; do
  printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>' \
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">' \
    '    <background android:drawable="@mipmap/ic_launcher_background" />' \
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />' \
    '</adaptive-icon>' > "$RES/mipmap-anydpi-v26/$n.xml"
done

echo "== 6. Small white icon shown in the status bar for reminders"
mkdir -p "$RES/drawable"
cat > "$RES/drawable/ic_stat_emta.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="640" android:viewportHeight="640">
  <group android:translateX="-192" android:translateY="-185">
    <path android:pathData="M302,790 L302,500 C302,370 410,300 512,220 C614,300 722,370 722,500 L722,790 Z"
        android:strokeColor="#FFFFFFFF" android:strokeWidth="44" android:strokeLineJoin="round" android:fillColor="#00000000" />
    <path android:pathData="M464,522 L640,522 M464,617 L640,617 M464,712 L640,712"
        android:strokeColor="#FFFFFFFF" android:strokeWidth="34" android:strokeLineCap="round" />
    <path android:pathData="M371,522 a31,31 0 1,0 62,0 a31,31 0 1,0 -62,0 M371,617 a31,31 0 1,0 62,0 a31,31 0 1,0 -62,0 M371,712 a31,31 0 1,0 62,0 a31,31 0 1,0 -62,0"
        android:fillColor="#FFFFFFFF" />
  </group>
</vector>
XML

echo "== 7. Copy the web app into the Android project"
npx cap sync android

echo "== 8. Same signing key every build, so updates install over the old app"
mkdir -p ~/.android
cp debug.keystore ~/.android/debug.keystore
cat >> android/app/build.gradle <<'GRADLE'

android {
    signingConfigs {
        debug {
            storeFile file("../../debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
}
GRADLE

echo "== 9. Build the APK"
cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon
