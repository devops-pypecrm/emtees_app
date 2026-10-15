# Emtees App — Windows Setup Guide

Follow this once on your Windows PC to build and run the Emtees Flutter app. It mirrors the setup the app was
built with (on a Mac). Read `HANDOVER.md` afterwards for how the app and its release process work.

> Windows can build the **Android** app. It cannot build iOS (that needs a Mac).
> Expect about **25 GB** of free disk space and a 20–40 minute first-time setup (mostly downloads).

---

## 0. The versions to match

| Tool | Version used by the original developer | Notes |
|---|---|---|
| Flutter | **3.44.9** (stable channel) | Dart **3.12.2** comes with it |
| JDK | **21** (project targets Java 17) | Any JDK **17 or newer** works. Android Studio's bundled JDK is fine. |
| Android Gradle Plugin | 9.0.1 | Downloaded automatically by the build |
| Gradle | 9.1.0 | Downloaded automatically by the build (first build takes a while) |
| Kotlin | 2.3.20 | Downloaded automatically |
| Android SDK Platforms | 34, 35, 36 (and 37) | Install 36 at minimum; 34 and 35 are also installed on the original machine |
| Android Build-Tools | 34.0.0 and 36.0.0 | |
| Android NDK | 28.2.13676358 | Install it in SDK Manager (side by side) |
| Git | 2.5x | |

You do **not** need to install Gradle, Kotlin or the Android Gradle Plugin yourself.

## 1. Install the tools

Do these in order. Use the default options unless told otherwise.

1. **Git for Windows** — https://git-scm.com/download/win
   (also gives you *Git Bash*, needed for the `.sh` scripts).
2. **Android Studio** (latest stable) — https://developer.android.com/studio
   It installs the Android SDK and a JDK for you. Start it once and let the *Setup Wizard* finish
   (choose **Standard** install).
3. **Flutter SDK 3.44.9.** Pick one:
   - **Recommended (exact version).** Open PowerShell:
     ```powershell
     mkdir C:\src
     cd C:\src
     git clone https://github.com/flutter/flutter.git -b stable
     cd flutter
     git checkout 3.44.9
     ```
     If `git checkout 3.44.9` says the version is not found, stay on `stable` and tell the person who gave you
     this guide which version `flutter --version` prints.
   - Or download the zip from https://docs.flutter.dev/install/archive and extract it to `C:\src\flutter`.
   Do **not** put Flutter in `C:\Program Files` or any folder with spaces or that needs admin rights.
4. **VS Code** (optional editor) — https://code.visualstudio.com, then install the *Flutter* extension.

## 2. Set environment variables

Windows Start menu → *Edit the system environment variables* → *Environment Variables…* → under **User
variables**:

1. Edit **Path** → **New** → add `C:\src\flutter\bin`.
2. **New** variable `ANDROID_HOME` = `C:\Users\<YourName>\AppData\Local\Android\Sdk`
   (this is Android Studio's default; confirm the real path in Android Studio →
   *Settings → Languages & Frameworks → Android SDK → Android SDK Location*).
3. Edit **Path** → **New** → add these two (replace the path if yours differs):
   - `C:\Users\<YourName>\AppData\Local\Android\Sdk\platform-tools`
   - `C:\Users\<YourName>\AppData\Local\Android\Sdk\cmdline-tools\latest\bin`
4. Optional but recommended: **New** variable `JAVA_HOME` = Android Studio's bundled JDK, usually
   `C:\Program Files\Android\Android Studio\jbr`.

Click OK on everything, then **close and reopen PowerShell** so the changes take effect.

## 3. Install the Android SDK pieces

Android Studio → **More Actions / Tools → SDK Manager**:

- **SDK Platforms** tab: tick **Android 16 (API 36)**, **Android 15 (API 35)** and **Android 14 (API 34)**.
  (Tick *Show Package Details* if you need to see the exact API numbers.)
- **SDK Tools** tab → tick *Show Package Details* and select:
  - **Android SDK Build-Tools** → `36.0.0` and `34.0.0`
  - **NDK (Side by side)** → `28.2.13676358`
  - **Android SDK Command-line Tools (latest)**
  - **Android SDK Platform-Tools**
  - **CMake** (optional)
- Click **Apply** and wait for the downloads.

Then accept the licenses in PowerShell (press `y` for each):

```powershell
flutter doctor --android-licenses
```

## 4. Two Windows settings that Flutter needs

1. **Developer Mode** (Flutter plugins need symbolic links): Windows *Settings → System → For developers →
   Developer Mode = On* (on Windows 10: *Update & Security → For developers*). Without it you get
   *"Building with plugins requires symlink support."*
2. **Long file paths**:
   ```powershell
   git config --global core.longpaths true
   ```
   and (run PowerShell **as Administrator** once):
   ```powershell
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```
   Also keep the project in a short path, e.g. `C:\dev\emtees_app`, not deep inside Documents/OneDrive.

If Windows Security / antivirus is very aggressive, add `C:\src\flutter` and your project folder to its
exclusions — it makes builds much faster.

## 5. Check everything

```powershell
flutter --version
flutter doctor -v
```

You want green checks for **Flutter**, **Android toolchain** and **Android Studio**.
(*Visual Studio – Windows desktop* and *Xcode* are not needed; ignore them.)
`flutter --version` should show **Flutter 3.44.9 / Dart 3.12.2**.

## 6. Get the project

```powershell
cd C:\dev
git clone <emtees_app GitHub URL>
cd emtees_app
flutter pub get
```

Then copy the two private files from the shared `handover-private` bundle into the project (see
`HANDOVER.md` §6):

| From the bundle | To |
|---|---|
| `android\key.properties` | `emtees_app\android\key.properties` |
| `android\app\upload-keystore.jks` | `emtees_app\android\app\upload-keystore.jks` |

## 7. Run it on a phone

1. On the phone: *Settings → About phone* → tap **Build number** 7 times → *Developer options* →
   turn on **USB debugging**.
2. Plug it into the PC and tap **Allow** on the phone's prompt.
3. Check it appears:
   ```powershell
   flutter devices
   ```
4. Run against the live backend:
   ```powershell
   flutter run --dart-define-from-file=config/prod.json
   ```
   The first build downloads Gradle and the Android dependencies and can take 10+ minutes. Later builds are fast.

(An emulator also works: Android Studio → *Device Manager* → create a device. For an emulator talking to a
backend on your own PC use `config/dev.json`; see `HANDOVER.md` §5.)

## 8. Build the release APK

```powershell
flutter build apk --release --dart-define-from-file=config/prod.json
```

Result: `build\app\outputs\flutter-apk\app-release.apk`. Publishing steps are in `HANDOVER.md` §8
(use **Git Bash** to run `./scripts/publish_release.sh`, or the `curl` command shown there).

## 9. Common problems

| Message | Fix |
|---|---|
| `flutter` is not recognized | `C:\src\flutter\bin` is not in Path, or PowerShell was not reopened. |
| `Unable to locate Android SDK` | Set `ANDROID_HOME`, or run `flutter config --android-sdk "C:\Users\<You>\AppData\Local\Android\Sdk"`. |
| `cmdline-tools component is missing` | SDK Manager → SDK Tools → install *Android SDK Command-line Tools (latest)*. |
| `Android license status unknown` | Run `flutter doctor --android-licenses` and accept all. |
| `Building with plugins requires symlink support` | Turn on Windows **Developer Mode** (§4). |
| `Filename too long` / path errors | Enable long paths (§4) and use a short project path. |
| `Could not find or install NDK` / missing build-tools | Install NDK `28.2.13676358` and Build-Tools `36.0.0` in SDK Manager (§3). |
| `Unsupported class file major version` / wrong Java | Use JDK 17 or newer (set `JAVA_HOME` to Android Studio's `jbr`). |
| First build seems stuck | It is downloading Gradle (~150 MB) and dependencies. Wait; check your internet connection. |
| Phone not listed in `flutter devices` | Re-plug, accept the USB debugging prompt, set the USB mode to *File transfer*, install your phone maker's USB driver. |
| Release build installs but cannot update the live app | The signing files from §6 are missing or different from the original ones. |
| `gradlew` missing | Run `flutter create --platforms=android .` once in the project folder (it does not overwrite your code). |

## 10. Quick checklist for the person setting up

- [ ] Git, Android Studio, Flutter 3.44.9 installed
- [ ] `Path`, `ANDROID_HOME` (and `JAVA_HOME`) set; PowerShell reopened
- [ ] SDK Platforms 34/35/36, Build-Tools 36.0.0 + 34.0.0, NDK 28.2.13676358, Command-line Tools installed
- [ ] `flutter doctor --android-licenses` accepted
- [ ] Developer Mode on, long paths enabled
- [ ] `flutter doctor -v` shows Flutter + Android toolchain green
- [ ] Repo cloned, `flutter pub get` done, signing files copied
- [ ] App runs on a phone with `--dart-define-from-file=config/prod.json`
