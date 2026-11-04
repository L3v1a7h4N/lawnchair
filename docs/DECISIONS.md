# Decisions

Lightweight ADRs. Each entry records the decision, why, and what would make us revisit it.
Status values: proposed · accepted · superseded.

---

## ADR-0001 — Base the launcher on Lawnchair 16, not raw AOSP Launcher3

**Status:** accepted (subject to owner confirmation)

**Decision.** Fork `LawnchairLauncher/lawnchair@16-dev`, rebrand it, and add Covers as a thin
overlay. Use AOSP Launcher3 `main` as the behavioural reference and patch source.

**Why.** Launcher3 has no standalone Gradle build; it is a Soong system app. Lawnchair is the
same codebase, already on `targetSdk 37`, Apache-2.0, and buildable today. Rebuilding the
launcher from scratch would cost months before the first real UX test, and UX is the point of
this project.

**Revisit if.** Lawnchair's upstream becomes unmaintainable, its licence changes, or the
rebrand cannot remove enough of the shell to feel like our product.

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

**Status:** accepted

**Decision.** Add `FLAG_COVER = 0x00000010` to `FolderInfo` and persist it through the existing
`LauncherSettings.Favorites.OPTIONS` integer.

**Why.** `options` is already written in `FolderInfo.onAddToDatabase` and read by the loader, and
it already carries `FLAG_MANUAL_FOLDER_NAME`, `FLAG_WORK_FOLDER`, etc. No schema migration, no
new table, no loader surgery. Backups that copy `favorites` keep the flag for free.

**Revisit if.** Covers need more metadata than a boolean (e.g., a per-cover custom face that is
not the first child, or a per-cover colour). Then add a `cover_config` JSON column with a proper
migration.

---

## ADR-0004 — The face is the first child, not a separate pointer

**Status:** accepted

**Decision.** The cover icon renders `FolderInfo.contents.get(0)`; reordering the folder changes
the face. A "Set as cover" action moves that item to rank 0.

**Why.** One source of truth. It matches the user's phrasing ("the first app in this folder
becomes the icon"), survives backup/restore, and avoids stale component names when apps are
updated or uninstalled.

**Revisit if.** Users want a face that is not in the folder, or want to pin a face while keeping
a different visual order.

---

## ADR-0005 — The gesture is scoped to the icon and arbitrated by direction

**Status:** accepted

**Decision.** Only a touch that starts inside the cover icon's bounds can open the folder; it must
become vertical (`|dy| > |dx|`) after touch slop. Arm at 24 dp, commit at 48 dp. Long-press wins
if it fires first.

**Why.** This is exactly why Nova's implementation did not break swipe-up-for-drawer or
swipe-down-for-notifications: the gesture is local to the icon. Global gestures stay global.

**Revisit if.** Usability testing shows people try to swipe the label or the gap between icons;
then expand the hit area vertically by up to 12 dp without expanding it horizontally.

---

## ADR-0006 — Default label is the face app's name

**Status:** proposed (needs owner decision)

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
