# Build and run

Verified on 2 November 2026 with a shallow clone of `LawnchairLauncher/lawnchair@16-dev`
(commit `f83fbb0`) on Windows 11, then installed on both test phones.

## Result

```
BUILD SUCCESSFUL in 7m 34s
643 actionable tasks: 492 executed, 151 from cache
APK: .tools/lawnchair-src/build/outputs/apk/lawnWithQuickstepGithub/debug/
     Lawnchair.16.Dev.(f83fbb0).github.debug.apk   (49 MB, debug)
```

| Device | API | Cold start (debug, first run) | Crash log |
|---|---|---|---|
| SM-S741B | 37 | 1672 ms | empty |
| SM-A546B | 36 | 3006 ms | empty |

Both launches were `am start -W` without changing the default home app. First-run times include
workspace creation and are not a performance baseline; they only prove the build runs on both
API levels.

## Toolchain

| Component | Version | Notes |
|---|---|---|
| Gradle | 9.8.2 | wrapper distribution |
| AGP | 9.5.0 | from `gradle/libs.versions.toml` |
| Kotlin | 2.4.21 | built-in Kotlin via AGP |
| JDK | 21 (CI) / 25 (this host) | see gotcha 3 |
| build-tools | 37.0.0 | SDK |
| compileSdk | 37.2 upstream, 37.0 in this spike | see gotcha 2 |
| targetSdk | 37 | |
| minSdk | 26 | |
| SDK platform | `android-37.0` installed | `android-37.2` is available but failed to install |

## Steps

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$tools = "C:\Users\Robert\developement\launcher\.tools"

# 1. Shallow clone with the SystemUI submodule (required)
git clone --depth 1 --branch 16-dev --recurse-submodules --shallow-submodules `
  https://github.com/LawnchairLauncher/lawnchair.git "$tools\lawnchair-src"

# 2. Point Gradle at the SDK
"sdk.dir=C\:\\Users\\Robert\\AppData\\Local\\Android\\Sdk" |
  Set-Content "$tools\lawnchair-src\local.properties" -Encoding ASCII

# 3. Spike-only: compile against 37.0 instead of 37.2
#    build.gradle: compileSdk { version = release(37) { minorApiLevel = 0 } }

# 4. Build (workspace-local Gradle home avoids the host lock issue)
$env:JAVA_HOME        = "C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot"
$env:ANDROID_HOME     = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:GRADLE_USER_HOME = "$tools\gradle-home"

cd "$tools\lawnchair-src"
gradle --console=plain assembleLawnWithQuickstepGithubDebug
```

The wrapper (`.\gradlew.bat`) is equivalent once `GRADLE_USER_HOME` is set and a working JDK is
selected. The extracted Gradle 9.8.2 binary was used here only to bypass a wrapper lock file.

## Install and smoke test

```powershell
$adb = "$sdk\platform-tools\adb.exe"
$apk = "$tools\lawnchair-src\build\outputs\apk\lawnWithQuickstepGithub\debug\Lawnchair.16.Dev.(f83fbb0).github.debug.apk"

& $adb -s RZGL81FQYEN install -r $apk      # API 37
& $adb -s R5CW90LKRDH install -r $apk      # API 36

# launch without changing the default home app
& $adb -s RZGL81FQYEN shell am start -W -n app.lawnchair.debug/app.lawnchair.LawnchairLauncher

# inspect
& $adb -s RZGL81FQYEN shell dumpsys activity activities | Select-String topResumedActivity
& $adb -s RZGL81FQYEN logcat -d -b crash

# return to the user's launcher
& $adb -s RZGL81FQYEN shell input keyevent KEYCODE_HOME
```

Package: `app.lawnchair.debug` (the `github` flavour adds `.debug`). Launcher activity:
`app.lawnchair.LawnchairLauncher`.

To actually make it the home app:

```powershell
& $adb -s <serial> shell cmd package set-home-activity app.lawnchair.debug/app.lawnchair.LawnchairLauncher
```

Do this only with the owner's agreement; the S741B currently runs Action Launcher as its home app.

## Host gotchas (all reproducible)

1. **Wrapper lock denied.** `gradlew.bat` failed with `FileNotFoundException ...gradle-9.8.2-bin.zip.lck
   (Zugriff verweigert)` when using `C:\Users\Robert\.gradle`. Setting `GRADLE_USER_HOME` to a
   workspace directory and invoking the extracted Gradle binary fixed it. A fresh
   `GRADLE_USER_HOME` also failed to create its own parent directories from Java, so the
   directory must exist before the build.
2. **`platforms;android-37.2` will not install.** `sdkmanager` (cmdline-tools latest, JDK 21)
   downloads and then fails with `Failed to read or create install properties file`, even though
   the SDK root is writable. The spike compiles against `android-37.0`. Options for the product
   build: retry with a fresh cmdline-tools, install the platform manually from the repository
   XML, or pin `compileSdk 37.0` deliberately.
3. **JDK 21 in `calendar/.tools/jdk21` cannot write files.** Java 21 starts but every
   `File.createNewFile()` fails with `Access denied`, including in `%TEMP%`, while JDK 25 and
   Node/cmd write normally. The build uses JDK 25. This is a host anomaly, not a project
   requirement; CI should still use a clean JDK 21.
4. **First build downloads a lot.** Expect ~7–10 minutes and several GB in `GRADLE_USER_HOME`
   on a warm network. Subsequent builds are incremental.

## What this proves

- The Lawnchair 16 source builds unmodified (except the compileSdk minor) on this host.
- The resulting APK targets API 37, runs on Android 16 and 17 Samsung hardware, and does not
  crash on launch.
- The Covers work can start from a known-good baseline rather than a build investigation.

## Next build milestone

Create the product fork, rename `applicationId` and the launcher label, then add
`FLAG_COVER` behind a debug flag and produce the first APK that opens a cover folder.
