# Build and run

Verified on 4 November 2026 on Windows 11, from the fork itself: `upstream/16-dev` at
`85493b9` plus the PR #7213 merge (`9debc69`), built with Android SDK platform 37.2.

## Result

```
BUILD SUCCESSFUL in 6m 20s
643 actionable tasks: 497 executed, 146 from cache
APK: build/outputs/apk/lawnWithQuickstepGithub/debug/
     Lawnchair.16.Dev.(9debc69).github.debug.apk   (49 MB, debug)
```

| Device | API | Test | Result |
|---|---|---|---|
| SM-S741B | 37 | Cold start | 1.54 s |
| SM-S741B | 37 | Long-press folder | "Enable cover mode" popup shown |
| SM-S741B | 37 | Tap cover icon | Launched `com.google.android.googlequicksearchbox/.SearchActivity` |
| SM-S741B | 37 | Swipe up on cover | Folder opened; Gmail, YouTube, Drive visible |

The A54 (API 36) ran the previous upstream-only build; re-verify it with this fork before beta.

## Toolchain

| Component | Version | Notes |
|---|---|---|
| Gradle | 9.8.2 | wrapper |
| AGP | 9.5.0 | `gradle/libs.versions.toml` |
| Kotlin | 2.4.21 | built-in Kotlin via AGP |
| JDK | 21 (CI) / 25 (this host) | see gotcha 1 |
| build-tools | 37.0.0 | |
| compileSdk / targetSdk | 37.2 / 37 | |
| minSdk | 26 | |
| SDK platform | `android-37.2` | see gotcha 2 |

## Quick start

```powershell
$env:JAVA_HOME   = "C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"

# one-time: point Gradle at the SDK
"sdk.dir=C\:\\Users\\Robert\\AppData\\Local\\Android\\Sdk" |
  Set-Content local.properties -Encoding ASCII

# build + install + launch (does not change the default home app)
.\scripts\build.ps1 -Install -Device RZGL81FQYEN -Launch
```

`scripts/build.ps1` sets `GRADLE_USER_HOME` to `.tools\gradle-home` when it is not already set, so
caches and the Gradle distribution stay inside the repo. The first run downloads Gradle and
dependencies; later builds are incremental.

Plain Gradle equivalent:

```powershell
.\gradlew.bat assembleLawnWithQuickstepGithubDebug
```

## Installing manually

```powershell
$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"
$apk = Get-ChildItem build\outputs\apk\lawnWithQuickstepGithub\debug\*.apk |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1

& $adb -s RZGL81FQYEN install -r $apk.FullName
& $adb -s RZGL81FQYEN shell am start -W -n app.lawnchair.debug/app.lawnchair.LawnchairLauncher

# return to the user's launcher
& $adb -s RZGL81FQYEN shell input keyevent KEYCODE_HOME
```

Package `app.lawnchair.debug`; launcher activity `app.lawnchair.LawnchairLauncher`. To make it the
home app (only with the owner's agreement):

```powershell
& $adb -s <serial> shell cmd package set-home-activity app.lawnchair.debug/app.lawnchair.LawnchairLauncher
```

## Testing cover mode by hand

1. Long-press a folder with at least two apps.
2. Choose **Enable cover mode**. The icon becomes the folder's first app.
3. Tap the icon → that app launches.
4. Swipe up on the icon → the folder opens.
5. Long-press again → **Disable cover mode** restores the grid icon.

`uiautomator dump` is useful for automation: the popup item has text `Enable cover mode`, and the
open folder exposes `folder_content` with each app's label.

## Host gotchas

1. **The JDK 21 in `calendar/.tools/jdk21` cannot write files.** Java 21 starts, but every
   `File.createNewFile()` fails with `Access denied`, even in `%TEMP%`; JDK 25 and Node/cmd write
   normally. The build uses JDK 25. CI should use a clean JDK 21.
2. **`sdkmanager` cannot install `platforms;android-37.2` into the expected path.** It downloads,
   then fails with `Failed to read or create install properties file`. If the directory already
   exists it installs to `android-37.2-2` and warns about an inconsistent location. The reliable
   fix is manual:

   ```powershell
   $zip = "$env:TEMP\android-37.2.zip"
   Invoke-WebRequest "https://dl.google.com/android/repository/platform-37.2_r02.zip" -OutFile $zip
   Expand-Archive $zip "$env:LOCALAPPDATA\Android\Sdk\platforms" -Force
   ```

   SHA-1: `d52b3062af96f7c4dfdca5a479cd1db33ae83762`.
3. **Gradle wrapper lock with the default home.** `C:\Users\Robert\.gradle` denied the wrapper's
   `.lck` file when the build ran under the broken JDK 21. Using JDK 25 and a repo-local
   `GRADLE_USER_HOME` avoids it; the scripts do this by default.
4. **First build is long.** ~6–10 minutes and a few GB in `.tools\gradle-home` on a warm network.

## What this proves

- The PR applies cleanly to current `16-dev` (auto-merge, no manual conflict).
- The combined tree compiles and targets API 37.
- The feature works on Samsung hardware: popup toggle, tap launch, swipe open.
- The sync/rollback path is ready; the missing piece is automated instrumentation.
