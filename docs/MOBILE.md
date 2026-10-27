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
Every screen fits a phone at every size (checked at 1280x720, 1600x720, 2400x1080,
1280x800 and 960x540, the 20:9 shapes with a notch): what does not fit scrolls.
On a short screen the skill tree moves its points, buttons and tree tabs into the
side column so the tree keeps the height.

**Menu > Touch layout** (under Text size) picks the layout: **Auto** (the default)
gives fingertip-sized buttons and "tap" / "hold" in the help on phones and tablets
only, so a laptop with a touch screen keeps the desktop layout; **On** and **Off**
force it either way, and a change mid-fight resizes the fight's buttons at once. It is saved beside the text size in `user://settings.cfg`
(`[ui] touch_layout`); a settings file from before it reads as Auto.

The life screen's two autopilot buttons ("Auto: this life", "Auto: 10 gens") each wait
after use: 60 and 300 seconds of real time (`data/ui/mobile.json`), greyed out with the time
left on the button ("Auto: 10 gens (4:32)") while play by hand carries on. The wait is kept
in `user://settings.cfg` (`[ui] autopilot_life_ready_at`, `autopilot_gens_ready_at`, Unix
time; capped to one cooldown from now, absent in older files), so closing the game does not
skip it. Only the buttons wait; GameBot and the balance harness do not.

Hold a finger on anything for half a second to read what a mouse would show on
hover (traits, skills, spells, feats, prices); a quick tap acts as a click; drag
to scroll. This works on any touch screen, whatever the touch layout says. A tap
never pops up the engine's own tooltip or a hover preview: only the hold bubble
shows. The mouse keeps its tooltips and hover as before, also on a laptop where
finger and mouse take turns on the same control. The Android back button
closes the top panel or opens the menu, and the game saves whenever it is sent to
the background. There is no Quit button on phones and tablets (iOS does not allow
an app to quit itself; Android apps are left with Home or Back); the desktop's
title screen keeps it.

## Party battles

With companions the fight is played a round at a time. A **party strip** shows one chip per
member (name, what they will do, HP and MP): in the top bar on a short screen (under 600 high,
where it takes the title's place), as a row of its own otherwise. The gold chip is the member being
asked; the commands below are theirs (their class skills, spells, feats, the shared potions). Pick,
and the next member is asked; when everyone has chosen, **Fight!** plays the round (**Flee!** if one
member's Flee covers the party). **Auto** sets that member to fight on their own (the class's
style), remembered for later rounds and battles; tap their chip to take over again. **Back** takes
the last choice back; **Repeat** (before anything is chosen) redoes last round's choices. Only
Auto and one of Back or Repeat sit beside the commands, so a short screen does not overflow. If
only one member needs orders, their pick plays at once, as in a solo hunt, which has no strip
and no Fight!. Chips are fingertip tall; a long press on a chip shows its HP, MP, statuses and
choice in full. Chip text steps down from the full wording to a short one, a smaller font and a
cut name, so nothing is ever clipped. The tunables are in `data/ui/mobile.json` (`party_chip_h`,
`party_chip_min_w`, `party_cmd_extra_w`, `held_pass_seconds`, `confirm_button_w`) and the chip
wordings in `data/combat/rounds.json`. A text-size or touch-layout change mid-round keeps what is
queued. The master Auto-battle button is unchanged and never uses the round.

In the skill tree a node that is open but cannot be bought now (too few points,
or mid-fight) has a green outline on a dark fill, apart from the green nodes that
can be bought and the dim locked ones; choosing it says why not now. Keystones
show the same green outline while they wait and a violet one while locked. A gold
(partly taken) node looks the same whether or not its next rank can be bought
now; choosing it tells.

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
