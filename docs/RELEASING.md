# Releasing

GitHub builds the Android APK and the Windows exe for you. Nothing has to be installed on your own machine.

## Make a release

1. On the repository page, open **Releases > Draft a new release**.
2. Under **Choose a tag**, type a new tag such as `v0.2.0` and pick **Create new tag on publish**. The tag must look like `v1.2.3` (a suffix such as `-rc.1` is fine). Anything else stops the build before it starts.
3. Write the notes and press **Publish release**.

The **Build and release** workflow (Actions tab) then runs, and when it finishes it adds three files to the release:

| File | What it is |
|---|---|
| `GenerationalLegacy-android-debug.apk` | The phone build, debug-signed like the APKs sideloaded so far |
| `GenerationalLegacy-windows-x86_64.exe` | One self-contained Windows program, no installer |
| `SHA256SUMS.txt` | Checksums of the two files above |

The Android version name is the tag without the `v`. The Android version code is the workflow's run number, so it only goes up.

If the build fails, the release stays without files. Fix the problem, then use **Re-run all jobs** on the failed run.

## Try a build without releasing

On the Actions tab, open **Build and release**, press **Run workflow**, and when it finishes download the **game-builds** zip from the run's page (kept for 14 days). A pull request that changes the workflow, the shared Godot setup or `export_presets.cfg` runs the same build as a check.

## Android signing

These APKs are **debug-signed**: fine for installing on your own phone, not for the Play Store (a signed release build is item 9 on the roadmap list).

Android installs an update over an installed app only when both are signed with the same key. Unless you give the workflow a key, each build makes a one-off key for itself, so a new APK will not install over an older one: **uninstall the old one first** (its saved games go with it). To keep one key for every build, store a keystore in the repository secrets once:

```bash
keytool -genkeypair -keystore game.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 game.keystore
```

Use the same password for the keystore and the key. Then, under **Settings > Secrets and variables > Actions**, add:

- `ANDROID_KEYSTORE_BASE64`: the output of the `base64` command
- `ANDROID_KEYSTORE_PASSWORD`: the password
- `ANDROID_KEY_ALIAS`: only if you used a different alias than `androiddebugkey`

Keep the `game.keystore` file somewhere safe. If it is lost, every phone has to uninstall and reinstall once. APKs already installed from other builds were signed with other keys, so they need that one uninstall too.

## Windows

The exe is not code-signed, so Windows SmartScreen may say "Windows protected your PC" the first time: choose **More info > Run anyway**.

## Changing the Godot version

The version and its checksums are set in one place, `.github/actions/setup-godot/action.yml`, which both the test and release workflows use. The checksums are in the `SHA512-SUMS.txt` file on the release at https://github.com/godotengine/godot-builds/releases (one for the editor zip, one for the export templates).
