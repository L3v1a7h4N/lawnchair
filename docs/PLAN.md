# Plan: Alcove, an Android 17 launcher with Covers

Status: Phase 0 complete apart from naming, 4 November 2026.
Companion documents: [research](RESEARCH.md) · [design](DESIGN.md) · [decisions](DECISIONS.md) ·
[build](BUILD.md) · [upstream policy](UPSTREAM.md).

## 1. Goal

Ship a daily-driver home screen for Samsung Galaxy A and S phones on Android 16–17 whose
signature interaction is a **cover folder**: the first app in a folder becomes the folder's icon,
tapping launches that app, swiping up opens the folder.

Success for v1, in order:

1. It is stable enough to be the default home app on the developer's own A54 and S741B for a week
   without a fallback launcher.
2. A new user can create a cover folder and discover the swipe without reading documentation.
3. It looks and moves like a product, not a Launcher3 build with a new icon.
4. Cold start and folder-open latency are at least as good as Lawnchair 16 on the same hardware.

Non-goals for v1: tablets/foldables, QuickStep/system recents, a theme engine, a feed, cloud
backup, iOS. Those are post-1.0.

## 2. The decision this plan is built on

**Fork Lawnchair 16 (`16-dev`), track it, and adopt PR #7213 for the cover feature.**

| | Lawnchair 16 | AOSP Launcher3 |
|---|---|---|
| Licence | Apache-2.0 | Apache-2.0 |
| Target | `targetSdk 37`, `compileSdk 37.2` | Android 17 `main` |
| Build | Gradle 9.8.2 / AGP 9.5, works today | Soong only; porting to Gradle is a project of its own |
| Parity | Widgets, folders, icon packs, search, backup, work profile | Reference behaviour, minimal polish |

Launcher3 remains the **reference** for behaviour. The buildable descendant is Lawnchair.

**The cover feature already exists**: [PR #7213 "feat: Add folder cover mode"](https://github.com/LawnchairLauncher/lawnchair/pull/7213)
is an open, mergeable, 11-commit PR based on `16-dev`. It implements the model, icon, tap, swipe,
long-press toggle, hotseat handling, notification dots and TalkBack access. The fork merges it
instead of maintaining a second implementation. When upstream merges it, the sync script detects
that and stops carrying the PR (see [UPSTREAM.md](UPSTREAM.md)).

**Plan B**, only if Lawnchair proves unmaintainable: port AOSP Launcher3 `main` to Gradle and keep
the same feature surface.

## 3. Product shape

- **Engine:** Launcher3 workspace, folders, drag layer, widget host, icon loader, database.
- **Shell we replace:** app name, icon, home layout defaults, search field, settings IA,
  onboarding, About, backup naming, and the "Lawnchair extras" group we do not want.
- **Signature feature:** Covers, delivered by PR #7213 on top of the existing `FolderInfo`
  options bitmask and `FolderIcon`; our work is the product layer around it.
- **Positioning:** the launcher Nova and Action Launcher users lost. Import from Nova/Lawnchair
  backups is a Phase 3 feature, not a gimmick — it is the migration path for the exact audience
  that wants Covers.

## 4. Phases

Estimates assume one developer plus an agent, focused. Multiply by 1.5 for calendar time.

### Phase 0 — Foundation and decision (week 1, 3–4 days)

- [x] Survey the environment: SDK 36/37, emulator, two physical devices.
- [x] Evaluate Launcher3, Lawnchair, Neo, Expressive, Launcher314.
- [x] Verify the cover-folder model against AOSP source (`FolderInfo.options`, `FolderIcon`).
- [x] Build Lawnchair 16 debug on this machine and record the exact toolchain.
- [x] Create the fork: upstream history, `main` branch, docs, Apache-2.0 notices.
- [x] Merge PR #7213 (11 commits) onto current `16-dev` — auto-merged with no conflicts.
- [x] Build the fork with SDK 37.2: `BUILD SUCCESSFUL in 6m 20s`, 49 MB debug APK.
- [x] Verify on the S741B (API 37): popup toggle, tap launches the face app, swipe opens the folder.
- [x] Add `scripts/sync-upstream.ps1` with cover detection, build gate, rollback and tags.
- [ ] Confirm the name (see §9); the fork currently ships under Lawnchair's app id/name.
- [ ] Re-run the smoke test on the A54 (API 36); record cold start and a baseline video.
- [ ] Set up CI (build on push, tag on success) and signing for release builds.

**Exit:** a signed debug APK of the fork runs as the default home app on both phones, with cover
mode, and a one-page baseline (cold start, first frame, folder open, crash-free session) exists.
Currently: the feature is verified on the S741B; branding, the A54 run, CI and the default-home
switch remain.

### Phase 1 — Brand and shell (weeks 1–2)

- Lock the name (Alcove recommended), run Play/DPMA/EUIPO/domain checks.
- Finalise the adaptive icon, monochrome layer, wordmark, Play icon and feature graphic.
- Implement the design tokens as a theme overlay: colour, type scale, shape, motion.
- Rebrand: application id `app.alcove.home`, launcher activity, app name in all locales,
  About/legal, remove Lawnchair-specific entry points, decide on the default grid (5×5).
- Replace the home layout: at-a-glance, page dots, dock, search pill.

**Exit:** a build that a stranger would not identify as Lawnchair; screenshots approved against
the mockups; no "Lawnchair" string visible in the UI.

### Phase 2 — Covers: adopt, then differentiate (weeks 1–3)

**The core is delivered by PR #7213** and merged into `main`. Do not rebuild it. What the PR
already provides:

- `FolderInfo.FLAG_COVER_MODE = 0x10`, persisted through the existing `OPTIONS` column;
- the folder icon renders the first preview item at full size;
- `ItemClickHandler` launches the face app; swipe up opens the folder;
- long-press popup with **Enable/Disable cover mode**, including a pre-drag condition so folder
  dragging still works;
- hotseat support and the touch-controller arbitration for workspace and dock;
- cover-app notification dot and count;
- TalkBack activation always opens the folder;
- cover artwork refresh after icon shape/theme changes.

Our Phase 2 work is the product layer around it:

1. **Affordance** — the 4 dp stacked edge and optional count badge on the cover icon, so a cover
   is distinguishable from a plain app. The PR currently draws a plain icon.
2. **Label policy** — decide face-app vs folder title (PR keeps the folder title), add the setting.
3. **Peek preview** — a short arm/commit gesture with haptic and a folder card that grows from the
   icon, instead of opening on release with no preview.
4. **Lifecycle UX** — one-app folder reverts with undo; empty folder removed; first-cover tooltip.
5. **Settings** — *Home screen → Covers*: count badge, haptics, label source, auto-convert.
6. **Automation** — unit tests for the flag round-trip; instrumented tap/swipe/long-press/rotate;
   a `scripts/test.ps1` that runs them on both devices.
7. **Design QA** — 420 dpi, light/dark, EN/DE, RTL, font scale 1.3, work profile, archived app.

**Exit:** the checklist in §6 passes on both devices; no regression in normal folders, drag and
drop, widget placement, or backup/restore.

Implementation notes for the enhancements (the PR has superseded the first ten sections):
[COVERS-SPEC.md](COVERS-SPEC.md).

### Phase 3 — Daily-driver polish (weeks 4–6)

- Onboarding: default-home request, restore from Lawnchair/Nova backup, create the first cover
  in-flow, gesture tutorial.
- Samsung tuning: 420 dpi layouts, One UI font scale, gesture-nav insets, predictive back,
  recents fallback behaviour, DeX/foldable guards (hidden in v1).
- Performance: cold start ≤ Lawnchair baseline, folder open input-to-first-frame < 100 ms,
  no jank in the peek animation (Macrobenchmark + JankStats).
- Privacy: remove unused network permissions/endpoints, write the privacy policy, confirm no
  telemetry, document what the launcher can see (app list, usage is local only).
- Localisation: English and German first; strings externalised, no hardcoded copy.

**Exit:** one week of self-use with no fallback; crash-free sessions > 99.5%; battery drain
within 2% of Lawnchair baseline over 24 h.

### Phase 4 — Beta and release (weeks 6–8)

- Internal testing track (or GitHub/F-Droid build if not publishing).
- 20–30 external testers, structured feedback on the five questions in DESIGN.md §5.
- Play listing: name, icon, screenshots, feature graphic, description, privacy policy,
  content rating, target API declaration.
- Release checklist: signed AAB, versioning, changelog, rollback plan, support channel.

**Exit:** v1.0 tag; store listing live (or reproducible release artefact); known-issues list.

## 5. Repo and upstream strategy

The repo is the fork: Lawnchair source at the root, with our additions beside it.

```
launcher/
  (Lawnchair 16-dev source: src/, lawnchair/, quickstep/, systemUI/, gradle/ ...)
  design/                 # mockups, icon sources, device screenshots
  docs/                   # product docs (upstream's docs/assets stays untouched)
  scripts/                # sync-upstream.ps1, build.ps1
  .tools/                 # ignored: gradle home, logs, scratch
```

Rules:

1. **Never reimplement the cover feature.** It is PR #7213's job until upstream absorbs it.
2. Our code goes in new files under `lawnchair/src/app/alcove/`; core edits stay small and are
   listed in the PR/upstream notes.
3. `main` only advances through `scripts/sync-upstream.ps1` (or an explicit merge of a tested
   commit); every successful build is tagged `alcove-last-good`.
4. Keep `docs/UPSTREAM.md` current when the tracking policy changes.
5. Do not rename `com.android.launcher3` classes; only the app-facing package/id changes in Phase 1.

## 6. Definition of done

### Core — implemented by PR #7213, verify on both devices

- [x] A folder can be marked as a cover from the long-press menu.
- [x] The cover shows the first app's icon instead of the grid preview.
- [x] Tap launches the first app (verified on the S741B).
- [x] Swipe up opens the folder (verified on the S741B).
- [ ] The state survives reboot, backup/restore and process death.
- [ ] The gesture is scoped to the icon: page swipes, drawer swipe and long-press drag never
      trigger it.
- [ ] Works in the hotseat as well as the workspace.
- [ ] Dropping an app on a cover adds it to the folder; drag/reorder still works.
- [ ] TalkBack activation opens the folder; the cover dot shows the face app's notifications.
- [ ] Works on API 36 and 37, 420 dpi, light/dark, EN/DE, RTL, font scale 1.3.

### Alcove enhancements — not yet built

- [ ] The stacked edge and optional count badge make a cover distinguishable from an app.
- [ ] Label mode: face app name vs folder title, with the chosen default.
- [ ] Peek preview with haptic before the folder commits to open.
- [ ] A one-app folder reverts with an undo snackbar; an empty folder is removed.
- [ ] One-time "swipe up to see all N apps" hint on the first cover.
- [ ] No new permissions; no network calls; no crash in 100 open/close cycles.

## 7. Test matrix

| Axis | Values |
|---|---|
| Devices | SM-A546B (API 36, 420 dpi), SM-S741B (API 37, 420 dpi), emulator API 36/37 |
| Device generations | Ax3 / S23 (Android 13–16) are covered by `minSdk 26`; add at least one (A33 or S23) to the matrix before beta |
| Display | 1080×2340, font scale 1.0/1.3, display size default/large |
| Theme | light, dark, dynamic colour from 3 wallpapers |
| Locale | en-US, de-DE, ar (RTL) |
| Folder | 1, 2, 6, 20 apps; work profile app; archived app; uninstalled face |
| Gesture | tap, swipe 24/48/80 dp, slow/fast, diagonal, long-press then drag, two fingers |
| System | gesture nav, 3-button nav, predictive back on/off, rotation, split screen |

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Lawnchair upstream churn breaks our patches | High | Medium | Thin overlay, patch queue, biweekly rebase, tested extension points |
| Cover gesture conflicts with drawer/page swipe | Medium | High | Scoped hit area, direction arbitration, instrumented gesture tests, settings escape hatch |
| Samsung animation limits make it feel cheap | High | Medium | Own the in-app motion; never imitate system transitions; set expectations in the listing |
| Name/trademark collision | Medium | High | Checks before brand spend; Cove fallback; package id independent of name |
| One-app folders and label confusion erode trust | Medium | Medium | Auto-revert + undo, label defaults to face app, usability test |
| Build environment fragility (JDK/SDK) | Medium | Low | Pin toolchain in CI, document host setup, build in a container if needed |
| Scope creep into a full launcher rewrite | High | High | Non-goals list; v1 keeps Lawnchair engine; no theme engine, no feed |
| Play policy / default-home role | Low | Medium | Standard `ROLE_HOME` request, no misleading Pixel branding, privacy policy |

## 9. Decisions needed from the owner

1. **Name:** Alcove (recommended), Cove, or another. Blocks icon/wordmark final and store check.
2. **Audience:** personal daily driver, open-source project, or commercial product? Determines
   licence headers, privacy policy, store fees and how much we strip.
3. **Default label:** the PR keeps the folder title (e.g. "Media" under a YouTube icon). Face-app
   name is still recommended for clarity; it is a Phase 2 enhancement and the single biggest
   comprehension risk.
4. **Swipe direction:** PR supports swipe up only. Reverse (down) is an enhancement; decide
   whether it is worth the extra gesture arbitration.
5. **Keep Lawnchair settings?** Recommended: keep them under *Advanced* for v1, replace the
   top-level IA with Alcove's four groups.

## 10. Next five actions

1. Run the naming checks (Play Store, DPMA/EUIPO) and lock the name.
2. Re-test the fork on the A54 (API 36) and record a baseline.
3. Build the first enhancement: stack edge + count badge on the cover icon, behind a debug flag.
4. Add `scripts/test.ps1` (unit + instrumented) and wire CI to run it before tagging.
5. Decide whether `main` becomes the default home app on the S741B for a week-long trial.
