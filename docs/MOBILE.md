# Playing on Android and iOS

The project ships two export presets in `export_presets.cfg`:

| Preset  | Builds                                   | Id                                   |
|---------|------------------------------------------|--------------------------------------|
| Android | an APK for arm64-v8a phones and tablets  | `com.dmgworkshop.generationallegacy` |
| iOS     | an Xcode project (built on a Mac)        | `com.dmgworkshop.generationallegacy` |

Both run in landscape (either way up), leave `tests/` and `docs/` out of the game
and keep the JSON data in. No keystore, password or Apple team id is committed:
Godot stores keystore paths and passwords in `.godot/export_credentials.cfg`,
which git ignores.

On a phone the game starts at 125% text size. Change it under **Menu > Text size**
(100%, 125%, 150%); the choice is saved on the device, not in the dynasty save.
Hold a finger on anything for half a second to read what a mouse would show on
hover (traits, skills, spells, feats, prices); a quick tap acts as a click; drag
to scroll. The Android back button closes the top panel or opens the menu, and
the game saves whenever it is sent to the background.

## Android, from Pop!_OS

Tested with Godot 4.7.2 on Linux: the export below produced a signed debug APK
(minSdk 24, targetSdk 36, arm64-v8a).

### 1. Java (JDK 17 or newer)

```sh
sudo apt update
sudo apt install openjdk-17-jdk
java -version          # should print 17 (21 works too)
```

### 2. Android SDK (command-line tools, no Android Studio needed)

```sh
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
export ANDROID_HOME=~/Android/Sdk
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"
```

(Any recent build-tools work; with 35.0.1 Godot prints "Could not find version of
build tools that matches Target SDK" and still signs the APK.)

For `adb` to see a phone over USB, install the udev rules and re-plug the phone:

```sh
sudo apt install android-sdk-platform-tools-common
sudo usermod -aG plugdev $USER     # then log out and back in
```

### 3. Godot export templates

In the Godot editor: **Editor > Manage Export Templates > Download and Install**.
Or download `Godot_v4.7.2-stable_export_templates.tpz` from the Godot 4.7.2
release page and use **Install from File**. They land in
`~/.local/share/godot/export_templates/4.7.2.stable/` (`android_debug.apk`,
`android_release.apk` and `ios.zip` are the ones used here).

### 4. Tell Godot where Java and the SDK are

**Editor > Editor Settings > Export > Android**:

- Java SDK Path: `/usr/lib/jvm/java-17-openjdk-amd64`
- Android SDK Path: `/home/<you>/Android/Sdk`

### 5. Keystores

Debug: Godot makes one by itself the first time the editor starts with a JDK
present (`~/.local/share/godot/keystores/debug.keystore`, alias
`androiddebugkey`, password `android`), and Editor Settings > Export > Android
points to it. To make it by hand:

```sh
mkdir -p ~/.local/share/godot/keystores
keytool -genkeypair -v -keystore ~/.local/share/godot/keystores/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Release (only for sharing or the Play Store; keep it and its password safe and
out of the repository, a lost key means the app can never be updated):

```sh
mkdir -p ~/keys
keytool -genkeypair -v -keystore ~/keys/generational-legacy.keystore \
  -alias generational-legacy -keyalg RSA -keysize 2048 -validity 10000
```

Then **Project > Export > Android > Keystore**: set Release, Release User
(`generational-legacy`) and Release Password. Godot keeps them in
`.godot/export_credentials.cfg`, never in `export_presets.cfg`.

### 6. Export the APK

In the editor: **Project > Export > Android > Export Project**, tick
**Export With Debug**, save as `build/android/GenerationalLegacy.apk`.

Or from a terminal in the project folder:

```sh
godot --headless --path . --export-debug "Android" build/android/GenerationalLegacy.apk
# release, once a release keystore is set:
godot --headless --path . --export-release "Android" build/android/GenerationalLegacy.apk
```

(`build/` is git-ignored.)

### 7. Install it on the phone

1. On the phone: **Settings > About phone**, tap **Build number** seven times;
   then **Settings > System > Developer options > USB debugging** on.
2. Plug the phone in, accept the "Allow USB debugging" prompt on it.
3. On the PC:

```sh
~/Android/Sdk/platform-tools/adb devices          # the phone is listed as "device"
~/Android/Sdk/platform-tools/adb install -r build/android/GenerationalLegacy.apk
~/Android/Sdk/platform-tools/adb logcat -s godot  # the game's output, for bug hunts
```

With the phone plugged in, the Android button at the top right of the Godot
editor (one-click deploy) exports, installs and starts the game in one go.

For the Play Store you need an Android App Bundle: in the Android preset turn on
**Gradle Build > Use Gradle Build**, set **Export Format** to AAB, and run
**Project > Install Android Build Template** once.

## iOS

Building for an iPhone or iPad needs things Linux cannot provide:

- a Mac with Xcode (Xcode compiles, signs and installs the app);
- an Apple ID: a free one lets Xcode put the game on your own device for 7 days
  at a time; the Apple Developer Program (99 USD a year) is needed for longer
  installs, TestFlight and the App Store;
- the 10-character Team ID of that account (Xcode > Settings > Accounts, or
  developer.apple.com > Membership).

What can be done on Pop!_OS is exporting the Xcode project. Godot refuses the
export until a Team ID is set (tested: "App Store Team ID not specified"), so
put yours in **Project > Export > iOS > Application > App Store Team ID**
(it stays on your machine if you do not commit `export_presets.cfg` afterwards)
and run:

```sh
godot --headless --path . --export-debug "iOS" build/ios/GenerationalLegacy.ipa
```

The preset has **Export Project Only** on, so instead of an `.ipa` this writes
`build/ios/GenerationalLegacy.xcodeproj` with the game's `.pck` and frameworks
beside it (tested on Linux with Godot 4.7.2; the project asks for landscape
left and right on iPhone and iPad). Copy the whole `build/ios/` folder to a Mac,
open the `.xcodeproj` in Xcode, pick your team under **Signing & Capabilities**,
plug in the device and press Run. For TestFlight or the App Store use
**Product > Archive** in Xcode.
