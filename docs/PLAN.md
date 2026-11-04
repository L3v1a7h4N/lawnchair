# Plan: Alcove, an Android 17 launcher with Covers

Status: Phase 0, 2 November 2026.
Companion documents: [research](RESEARCH.md) · [design](DESIGN.md) · [decisions](DECISIONS.md) · [build](BUILD.md).

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

**Fork Lawnchair 16 (`16-dev`) and rebrand it; do not start from AOSP Launcher3.**

| | Lawnchair 16 | AOSP Launcher3 |
|---|---|---|
| Licence | Apache-2.0 | Apache-2.0 |
| Target | `targetSdk 37`, `compileSdk 37.2` | Android 17 `main` |
| Build | Gradle 9.8.2 / AGP 9.5, works today | Soong only; porting to Gradle is a project of its own |
| Parity | Widgets, folders, icon packs, search, backup, work profile | Reference behaviour, minimal polish |
| Time to first install | Hours | Weeks |

Launcher3 remains the **reference** for behaviour and for patches. The buildable descendant is
Lawnchair. Full comparison and citations: [RESEARCH.md](RESEARCH.md).

**Plan B**, only if Lawnchair proves unmaintainable or its branding cannot be removed cleanly:
port AOSP Launcher3 `main` to Gradle using Lawnchair's build plumbing (`prebuilts/`,
`hidden-api/`, SystemUI submodule) and keep the Covers code, which is designed to be
launcher-agnostic.

## 3. Product shape

- **Engine:** Launcher3 workspace, folders, drag layer, widget host, icon loader, database.
- **Shell we replace:** app name, icon, home layout defaults, search field, settings IA,
  onboarding, About, backup naming, and the "Lawnchair extras" group we do not want.
- **Signature feature:** Covers, implemented on top of the existing `FolderInfo` options bitmask
  and `FolderIcon` (see [DESIGN.md](DESIGN.md) and the technical notes below).
- **Positioning:** the launcher Nova and Action Launcher users lost. Import from Nova/Lawnchair
  backups is a Phase 3 feature, not a gimmick — it is the migration path for the exact audience
  that wants Covers.

## 4. Phases

Estimates assume one developer plus an agent, focused. Multiply by 1.5 for calendar time.

### Phase 0 — Foundation and decision (week 1, 3–4 days)

- [x] Survey the environment: SDK 36/37, emulator, two physical devices.
- [x] Evaluate Launcher3, Lawnchair, Neo, Expressive, Launcher314.
- [x] Verify the cover-folder model against AOSP source (`FolderInfo.options`, `FolderIcon`).
- [x] Build Lawnchair 16 debug on this machine and record the exact toolchain (`7m 34s`, API 37).
- [x] Install on the A54 (API 36) and S741B (API 37); cold-start smoke test with no crash.
- [ ] Record the baseline properly: 60 s video, `gfxinfo`, folder open, drawer, widgets, gesture
      nav. (The build is installed and launching; it has not been set as the default home app.)
- [ ] Confirm name and licence intent with the owner (see §9).
- [ ] Create the product fork: `upstream` remote, `main` branch, CI, signing, licences.

**Exit:** a signed debug APK of the rebranded fork runs as the default home app on both phones,
and a one-page baseline (cold start, first frame, folder open, crash-free session) exists.
Currently: upstream build verified and launched on both phones; the default-home switch and the
product fork are still open.

### Phase 1 — Brand and shell (weeks 1–2)

- Lock the name (Alcove recommended), run Play/DPMA/EUIPO/domain checks.
- Finalise the adaptive icon, monochrome layer, wordmark, Play icon and feature graphic.
- Implement the design tokens as a theme overlay: colour, type scale, shape, motion.
- Rebrand: application id `app.alcove.home`, launcher activity, app name in all locales,
  About/legal, remove Lawnchair-specific entry points, decide on the default grid (5×5).
- Replace the home layout: at-a-glance, page dots, dock, search pill.

**Exit:** a build that a stranger would not identify as Lawnchair; screenshots approved against
the mockups; no "Lawnchair" string visible in the UI.

### Phase 2 — Covers MVP (weeks 2–4)

The technical core, in dependency order:

1. **Model** — `FolderInfo.FLAG_COVER = 0x10`, `isCover()`, `setCover(boolean, ModelWriter)`.
   Persisted through the existing `OPTIONS` column; no schema migration. Unit tests for
   read/write/round-trip and for folders loaded from old databases.
2. **Face resolution** — `FolderInfo.getCoverItem()` returns `contents.get(0)` if non-empty;
   define behaviour for work-profile items, app pairs, and archived apps.
3. **Icon rendering** — a `CoverPreview` mode in `FolderIcon`/`PreviewItemManager`: draw one
   item at full size, then the stacked edge (2 dp) and optional count badge. Reuse
   `FastBitmapDrawable` and the existing icon cache; do not decode new bitmaps.
4. **Click routing** — `ItemClickHandler` launches the face for cover folders, opens the folder
   otherwise. Long-press still goes to the folder menu.
5. **Gesture** — a small `CoverGestureDetector` owned by `FolderIcon`: track vertical drags that
   begin inside the icon, arm at 24 dp, commit at 48 dp, cancel on horizontal slop or long-press.
   The peek preview drives the existing folder open animation from the icon bounds.
6. **Folder surface** — reuse `Folder`/`FolderPagedView`, restyle the card, add the title,
   count and Edit affordance; close on outside tap, back, and swipe down.
7. **Conversion UX** — "Make cover" in the folder menu, "Stop using cover", auto-revert at one
   app, one-time tooltip on first creation.
8. **Settings** — *Home screen → Covers*: enable, count badge, haptic peek, swipe direction,
   label source, convert-on-creation.
9. **Accessibility** — content descriptions, custom action "Open folder", TalkBack traversal,
   reduced-motion path, 48 dp minimum targets.
10. **Tests** — unit tests for model and gesture thresholds; instrumented tests for tap vs swipe,
    long-press, drag, rotation, and process death; manual matrix on both devices.

**Exit:** the checklist in §6 passes on both devices; no regression in normal folders, drag and
drop, widget placement, or backup/restore.

File-level implementation spec (classes, touch math, tests): [COVERS-SPEC.md](COVERS-SPEC.md).

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

Lawnchair moves daily. We keep the diff small and rebasable:

```
launcher/
  .tools/lawnchair-src/        # read-only upstream clone (not committed)
  app/                         # our Gradle project, Lawnchair source as a submodule or vendored
  design/                      # mockups, icon sources, tokens
  docs/
  patches/                     # one .patch per upstream file we touch, regenerated on rebase
```

Rules:

1. Prefer **new files** under `lawnchair/src/app/alcove/` over edits to Launcher3 files.
2. Every core edit is ≤ 30 lines and lives in `patches/` with a note on why it cannot be an
   extension point.
3. Rebase on `upstream/16-dev` every two weeks; run the Covers test suite before and after.
4. Never rename `com.android.launcher3` classes; only the app-facing package/id changes.
5. Keep a `docs/UPSTREAM.md` log of upstream commits that touch `FolderIcon`, `Folder`,
   `ItemClickHandler`, `FolderInfo`, or the database.

## 6. Definition of done for Covers (v1)

- [ ] A folder can be marked as a cover; the state survives reboot, backup/restore, and process
      death.
- [ ] The cover shows the first app's icon, the stacked edge, and (optionally) the count.
- [ ] Tap launches the first app; 50/50 taps land on the app, not the folder.
- [ ] Swipe up opens the folder in < 100 ms input-to-frame with a peek preview and one haptic tick.
- [ ] Swipe is scoped to the icon; page swipes, drawer swipe, and long-press drag never trigger it.
- [ ] Long-press offers Open folder, Change cover app, Folder settings, Remove.
- [ ] Dropping an app on a cover adds it to the folder; the drop preview shows the 2×2 grid.
- [ ] A one-app folder reverts with an undo snackbar; an empty folder is removed.
- [ ] TalkBack can open the folder without the gesture and reads the face app + count.
- [ ] Works on API 36 and 37, 420 dpi, light/dark, EN/DE, RTL, font scale 1.3.
- [ ] No new permissions; no network calls; no crash in 100 folder open/close cycles.

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
3. **Default label:** face app name (recommended) or folder name? This is the single biggest
   comprehension risk.
4. **Default swipe direction:** up (recommended) or down? Up matches the mental model; down is
   better for one-handed use on a 6.5" phone.
5. **Keep Lawnchair settings?** Recommended: keep them under *Advanced* for v1, replace the
   top-level IA with Alcove's four groups.

## 10. Next five actions

1. Install the current Lawnchair build on both phones; capture a 60-second baseline video and
   `dumpsys gfxinfo` numbers.
2. Create the fork: `git remote add upstream`, branch `alcove/main`, rename app id + label,
   commit the first rebrand.
3. Build the Covers spike: `FLAG_COVER` + face icon + tap-launch, behind a debug flag. Demo on
   the S741B.
4. Run the two naming checks (Play Store, DPMA/EUIPO) and lock the name.
5. Approve the mockups and the interaction rules in DESIGN.md, or mark changes.
