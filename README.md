# Alcove (working name)

A Samsung-first Android 17 home screen whose signature idea is simple: **a folder wears its
first app as its face. Tap launches that app. Swipe up opens the folder.**

![Alcove concepts](design/mockups.png)

> Status: **Phase 0 — plan, research, design and a verified upstream build.** No Alcove code has
> been written yet; this repo holds the decision record, the design system and a working baseline
> build that has run on both test phones.

## Why this exists

The interaction is not new. Nova called it *Swipe to open folder*; Action Launcher called it
*Covers*. Both apps are effectively discontinued, and the maintained open-source launchers lost
the feature — Lawnchair's request for it has been open since 2022. It turns a home screen into a
single page of one-tap apps with every group one swipe away:

> **Best case:** open your favourite app with a single tap.
> **Worst case:** open any other app with a swipe and a tap.

Alcove is a bet that this one behaviour, done properly, is worth more than another grid of
settings.

## The plan in one table

| Phase | Outcome | Status |
|---|---|---|
| 0 · Foundation | Base chosen, build verified, devices baselined, name/licence confirmed | Research + build done, owner decisions open |
| 1 · Brand & shell | Name, icon, tokens, rebranded home layout | Not started |
| 2 · Covers MVP | Model, icon, tap, swipe, peek, settings, a11y, tests | Not started |
| 3 · Daily-driver polish | Onboarding, Samsung tuning, performance, privacy, EN/DE | Not started |
| 4 · Beta & release | Testers, store listing, signed release | Not started |

Full breakdown with exit criteria and risks: **[docs/PLAN.md](docs/PLAN.md)**.

## Documents

| Document | What is in it |
|---|---|
| [docs/RESEARCH.md](docs/RESEARCH.md) | Fork comparison, licensing, Launcher3 internals, the cover-mode paper trail, API 37 and One UI constraints, build findings |
| [docs/PLAN.md](docs/PLAN.md) | Phases, work breakdown, definitions of done, test matrix, risks, next actions |
| [docs/DESIGN.md](docs/DESIGN.md) | Naming, icon concepts, the Covers interaction spec, gesture arbitration, visual language, usability questions |
| [docs/DECISIONS.md](docs/DECISIONS.md) | ADRs: base, licence, storage, face selection, gesture scope, label, QuickStep, package id, minSdk |
| [docs/COVERS-SPEC.md](docs/COVERS-SPEC.md) | File-level implementation spec: model, rendering, click routing, gesture, settings, tests |
| [docs/BUILD.md](docs/BUILD.md) | Exact toolchain, the working build command, host-specific gotchas, install/test commands |

## Design

| UI concepts | Icon concepts |
|---|---|
| ![UI](design/mockups.png) | ![Icons](design/icons.png) |

The mockups are rendered from HTML: [`design/mockups.html`](design/mockups.html) and
[`design/icons.html`](design/icons.html).

## Base

**Lawnchair 16** (`16-dev`), the Android 16-based Launcher3 derivative:

- Apache-2.0; `targetSdk 37`, `compileSdk 37.2`, `buildTools 37.0.0`, `minSdk 26`
- Gradle 9.8.2, AGP 9.5.0, Kotlin 2.4.21, JDK 21 in CI
- Workspace, folders, widgets, icon packs, search, backup, work profile and private space already
  implemented
- Covers is a contained change: `FolderInfo` already persists an `options` bitmask, and
  `FolderIcon` is a `FrameLayout` with a pluggable click listener

AOSP Launcher3 remains the reference implementation and the source of behaviour patches.
See [ADR-0001](docs/DECISIONS.md).

![Lawnchair baseline on the S741B](design/device-lawnchair-baseline.png)

*The verified upstream build running on the S741B (Android 17). The S741B currently uses Action
Launcher as its home app — the discontinued launcher that popularised Covers — which is exactly
the habit this project is designed around.*

## Quick start (this machine)

```powershell
$env:JAVA_HOME   = "C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:GRADLE_USER_HOME = "C:\Users\Robert\developement\launcher\.tools\gradle-home"

cd .tools\lawnchair-src
gradle assembleLawnWithQuickstepGithubDebug
```

The APK lands under `.tools\lawnchair-src\build\outputs\apk\`. Verified: **7m 34s, 49 MB debug
APK, launches on API 36 and 37 without a crash.** This host cannot install SDK platform 37.2, so
the scratch clone compiles against 37.0; see [docs/BUILD.md](docs/BUILD.md) for that and the JDK
gotcha.

```powershell
# install, then launch without changing the default home app
adb -s RZGL81FQYEN install -r <apk>
adb -s RZGL81FQYEN shell am start -W -n app.lawnchair.debug/app.lawnchair.LawnchairLauncher

# only if you want it to become the home app
adb -s RZGL81FQYEN shell cmd package set-home-activity app.lawnchair.debug/app.lawnchair.LawnchairLauncher
```

The upstream clone in `.tools/` is a scratch build, not our source tree. The product fork still
has to be created (Phase 0, next actions).

## Test devices

| Device | Model | Android | API | Notes |
|---|---|---|---|---|
| Galaxy A54 | SM-A546B | 16 | 36 | Lower bound of the target range |
| Galaxy S (2026 FE) | SM-S741B | 17 | 37 | Current API level, primary design target |

Both are 1080 × 2340 at 420 dpi effective — 411 × 891 dp.

## Immediate next steps

1. Record the baseline on both phones (cold start, folder open, drawer, widgets, gesture nav);
   the build is installed and launching already, but not set as the default home app.
2. Lock the name (Alcove recommended) with Play Store and DPMA/EUIPO checks.
3. Create the product fork and rebrand the shell.
4. Build the Covers spike behind a debug flag: `FLAG_COVER`, face icon, tap-to-launch.
5. Approve or amend the interaction rules in [docs/DESIGN.md](docs/DESIGN.md).

## Licence

Apache-2.0, inherited from AOSP Launcher3 and Lawnchair. Attribution notices are retained; see
`LICENSE` and `NOTICE` when the fork is created.
