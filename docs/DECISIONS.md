# Decisions

Lightweight ADRs. Each entry records the decision, why, and what would make us revisit it.
Status values: proposed · accepted · superseded.

---

## ADR-0001 — Base the fork on Lawnchair 16 and track `16-dev`

**Status:** accepted

**Decision.** This repository **is** the fork: Lawnchair `16-dev` history at the root, Alcove
docs/scripts beside it. Track `upstream/16-dev` with `scripts/sync-upstream.ps1`; never start
from raw AOSP Launcher3.

**Why.** Launcher3 has no standalone Gradle build; it is a Soong system app. Lawnchair is the
same codebase, already on `targetSdk 37`, Apache-2.0, and buildable today. A full fork (rather than
a patch overlay or submodule) keeps the build simple, lets the repo be pushed as a real GitHub
fork, and gives the sync script a single branch to gate on.

**Revisit if.** Lawnchair's upstream becomes unmaintainable or its licence changes.

---

## ADR-0002 — Licence: Apache-2.0, keep our additions Apache-2.0

**Status:** accepted

**Decision.** Keep the Apache-2.0 licence and NOTICE files; license our new code under the same
terms unless the owner chooses otherwise.

**Why.** Lawnchair and AOSP Launcher3 are Apache-2.0. It permits closed distribution, which keeps
the door open for a paid product or a personal build. Neo Launcher (GPL-3.0) would force us to
publish modifications; we may still read its code for ideas, but we must not copy GPL code.

**Revisit if.** The owner wants a GPL community project, or wants to upstream Covers to Lawnchair
(which would require the contribution to be Apache-2.0 compatible — it is).

---

## ADR-0003 — Store cover state in `FolderInfo.options`, not a new column

**Status:** accepted; implemented by PR #7213 as `FLAG_COVER_MODE`

**Decision.** Use the existing `FolderInfo.options` bitmask and the `LauncherSettings.Favorites.OPTIONS`
integer. The PR names the bit `FLAG_COVER_MODE = 0x00000010`.

**Why.** `options` is already written in `FolderInfo.onAddToDatabase` and read by the loader, and
it already carries `FLAG_MANUAL_FOLDER_NAME`, `FLAG_WORK_FOLDER`, etc. No schema migration, no
new table, no loader surgery. Backups that copy `favorites` keep the flag for free.

**Revisit if.** Covers need more metadata than a boolean (e.g., a per-cover custom face that is
not the first child, or a per-cover colour). Then add a `cover_config` JSON column with a proper
migration.

---

## ADR-0004 — The face is the first child, not a separate pointer

**Status:** accepted

**Decision.** The cover icon renders the folder's first preview item; the PR resolves it through
`FolderCoverMode.getCoverItem()` (`getPreviewItemsOnPage(0).firstOrNull()`), so reordering the
folder changes the face. Items that cannot stand in for a single app (e.g. app pairs) fall back
to the normal folder icon.

**Why.** One source of truth. It matches the user's phrasing ("the first app in this folder
becomes the icon"), survives backup/restore, and avoids stale component names when apps are
updated or uninstalled.

**Revisit if.** Users want a face that is not in the folder, or want to pin a face while keeping
a different visual order.

---

## ADR-0005 — The gesture is scoped to the icon, never global

**Status:** accepted; implemented by PR #7213

**Decision.** Only a touch that starts inside the cover icon's bounds can open the folder. The PR
builds it on Lawnchair's existing `DirectionalGestureListener` and teaches `Workspace`,
`Hotseat`, `PortraitStatesTouchController` and `VerticalSwipeTouchController` to back off when
the touch is on a cover icon. The 24/48 dp arm/commit thresholds in [DESIGN.md](DESIGN.md) are the
target for the peek enhancement, not current behaviour.

**Why.** This is exactly why Nova's implementation did not break swipe-up-for-drawer or
swipe-down-for-notifications: the gesture is local to the icon. Global gestures stay global.

**Revisit if.** Usability testing shows people try to swipe the label or the gap between icons;
then expand the hit area vertically by up to 12 dp without expanding it horizontally.

---

## ADR-0006 — Default label is the face app's name

**Status:** proposed (needs owner decision); PR currently keeps the folder title

**Decision.** Under a cover, show the face app's label; the folder title is available in the
folder card and can be chosen in Settings instead.

**Why.** The icon shows YouTube; the label should say YouTube. Showing "Media" under a YouTube
icon is the most likely source of tap errors. Nova and Action both lean toward showing the app.

**Revisit if.** User testing shows the folder name is needed to find groups; then default to the
folder name and add a subtitle/count to disambiguate.

---

## ADR-0007 — No QuickStep / custom recents in v1

**Status:** accepted

**Decision.** Ship as a standard home app; use the system recents. Do not bundle QuickStep or
require root.

**Why.** Lawnchair's QuickSwitch integration is root-only and documented for Android 15–16;
our target is 17. Samsung does not honour `GestureNavContract` for third-party launchers. A
half-working recents implementation is worse than the system's.

**Revisit if.** Google opens the recents/animation APIs to third-party launchers, or a
non-root QuickStep path appears for Android 17.

---

## ADR-0008 — Package id `app.alcove.home`, class names unchanged

**Status:** proposed

**Decision.** Change `applicationId` and the launcher component's `resValue`, plus the user-facing
app name. Keep `com.android.launcher3.*` and `app.lawnchair.*` class names in v1.

**Why.** Renaming thousands of classes creates a merge conflict with every upstream commit and
gains nothing at runtime. The app id and the launcher activity are the only places the system
and the user see the identity.

**Revisit if.** We detach from upstream and want a clean namespace for a long-lived fork.

---

## ADR-0009 — Keep `minSdk 26` for v1

**Status:** accepted

**Decision.** Do not raise `minSdk` from Lawnchair's 26, even though the target devices are
Android 13+.

**Why.** Raising it only reduces test surface and APK size marginally, while forcing code churn
in compat layers. The product supports older devices for free; we simply do not test below 33.

**Revisit if.** A v1 API we need is 33+, or supporting old devices costs real QA time.

---

## ADR-0010 — Carry PR #7213 as a merge; drop it automatically when upstream ships it

**Status:** accepted

**Decision.** The fork does not own a cover implementation. `main` contains a merge of
`refs/pull/7213/head`, and `scripts/sync-upstream.ps1` merges the PR only while
`upstream/16-dev` does not contain cover mode (detected by searching for `FLAG_COVER` /
`FolderCoverMode`).

**Why.** The PR already covers the hard parts the first plan underestimated: hotseat hit testing,
touch-controller arbitration, notification dots, TalkBack activation, long-press popup and icon
refresh after shape/theme changes. A second implementation would drift and duplicate review work.
Detecting by source rather than by PR state makes the transition to upstream automatic.

**Revisit if.** The PR is closed without merging, or upstream merges a materially different
implementation. In the first case, move the feature into fork-owned code; in the second, delete
the PR merge and keep upstream's version.

---

## ADR-0011 — The repository is the full fork, not an overlay

**Status:** accepted

**Decision.** Keep Lawnchair source at the repo root with upstream history, plus `design/`,
`docs/` and `scripts/`. Do not use a submodule or a patch-only overlay.

**Why.** It builds with the stock Gradle wrapper, can be pushed as a real GitHub fork, and gives
the sync script a single branch to gate. The extra disk cost is acceptable on this machine.
`docs/` sits beside upstream's `docs/assets` without colliding.

**Revisit if.** Repository size becomes a distribution problem, or upstream history diverges so
far that a rebase is preferable to merges.
