# Covers: implementation notes and enhancement backlog

> **Superseded as an implementation plan by [PR #7213](https://github.com/LawnchairLauncher/lawnchair/pull/7213),
> which is merged into this fork.** The PR already implements the model, rendering, click routing,
> swipe gesture, long-press toggle, hotseat handling, notification dots and accessibility, under
> different names than the original sketch below: `FolderInfo.FLAG_COVER_MODE`,
> `app.lawnchair.folder.FolderCoverMode`, `FolderCoverModeGestureListener`, `FolderLongPress`.
>
> Read sections 1–7 as the original design record, not as instructions. The parts still worth
> building are the product layer: the stacked edge, the count badge, the label policy, the peek
> preview and the first-run tutorial. Sections 2, 6, 8–10 remain useful for those.

This was the bridge between [DESIGN.md](DESIGN.md) and the first implementation attempt. It names
the Launcher3 extension points verified in AOSP `main` and Lawnchair `16-dev`.

## 1. Data model (implemented by the PR)

The fork uses `PR #7213`'s API:

```java
// FolderInfo
public static final int FLAG_COVER_MODE = 0x00000010;
```

`FolderCoverMode.isEnabled(info)`, `getCoverItem(folderIcon)` and
`launchCoverApp(view, folderIcon)` hold the shared logic; the icon owns `toggleCoverMode()` and
`updateCoverMode()`. Persistence is still the existing `OPTIONS` column, so no schema change.

The original sketch below used `FLAG_COVER` / `getCoverItem()` on `FolderInfo`; the PR reads the
first *preview* item instead, which also handles app pairs and reordering.

Rules:

- A cover requires `getCoverItem() != null`. `isCover()` alone is not enough; callers must check
  both, because a folder can be mid-removal.
- When a child is removed and only one remains, clear the flag with `setCover(false, writer)` from
  the model update and show the undo snackbar.
- `FLAG_WORK_FOLDER` and `FLAG_ITEMS_SORTED` are orthogonal; do not clear them.

## 2. Rendering

`FolderIcon` is a `FrameLayout`; its `dispatchDraw` currently draws the preview grid through
`PreviewItemManager`. A one-item preview is **not** full size — `ClippedFolderIconLayoutRule`
clamps to two items and scales to ~0.51. So do not fake a cover by filtering the preview list.

In `FolderIcon.dispatchDraw`, before the existing preview block:

```java
if (mInfo.isCover() && mInfo.getCoverItem() != null) {
    drawCover(canvas);   // stack edge + face at full size + optional count
    drawDot(canvas);     // notification dot still applies
    return;
}
```

`drawCover`:

1. **Stack edge** — a rounded rect at the icon bounds, translated up by 4 dp and scaled 0.96,
   filled with 14% white and a 1 dp 30% white stroke. Cache it as a `Drawable`/`Paint`; do not
   allocate per frame.
2. **Face** — the first child's icon at the full `iconSizePx`, centred. Reuse the existing
   drawable from `PreviewItemManager` (expose a `getOrCreateDrawable(ItemInfo)` helper) so the
   icon cache, themed icons, icon packs and work-profile badges keep working.
3. **Count badge** — small pill, bottom-right, only if `CoverPrefs.showCount` is true. Text
   `contents.size()`, 10.5 sp, `#17130F` on `#F7F1E6` with a 1 dp outline. Mirror to bottom-left
   in RTL.
4. **Label** — `mFolderName` text becomes the face app's title when `CoverPrefs.labelMode == APP`
   (default), otherwise the folder title. Recompute in `updatePreviewItems`,
   `onItemsChanged`, and `onTitleChanged`; guard against a null face.

Hit-testing: `FolderIcon.shouldIgnoreTouchDown` already rejects touches outside padding; keep it.
The drawable and the touch target must agree — both are `iconSizePx`.

## 3. Click routing

`ItemClickHandler.onClickFolderIcon(View v)` currently always opens the folder. Change it to:

```java
private static void onClickFolderIcon(View v) {
    FolderIcon icon = (FolderIcon) v;
    Folder folder = icon.getFolder();
    if (folder.isOpen() || folder.isDestroyed()) return;

    FolderInfo info = folder.mInfo;
    if (info.isCover() && info.getCoverItem() != null) {
        ItemInfo face = info.getCoverItem();
        // Reuse the normal app/shortcut launch path, including disabled-app handling,
        // pending installs, work profile and adaptive icon animation.
        onClickAppShortcut(v, (WorkspaceItemInfo) face, Launcher.getLauncher(v.getContext()));
        return;
    }
    folder.animateOpen();
    StatsLogManager...log(LAUNCHER_FOLDER_OPEN);
}
```

If the face is not a `WorkspaceItemInfo` (e.g. a shortcut), fall back to
`startAppShortcutOrInfoActivity(v, face, launcher)` after making it accessible to the handler, or
keep the folder open behaviour. Do not duplicate launch logic.

## 4. Gesture (implemented differently by the PR)

The PR uses Lawnchair's `DirectionalGestureListener` via `FolderCoverModeGestureListener` and
teaches `Workspace`, `Hotseat` and the two touch controllers to yield to cover icons. The custom
thresholds below are the *peek enhancement*, not current behaviour.

```java
private static final float ARM_DP = 24f;      // start peeking
private static final float COMMIT_DP = 48f;   // open on release
private static final float VELOCITY = 800f;   // dp/s, fast flick shortcut

private boolean mCoverArmed;
private float mDownX, mDownY;
private int mTouchSlop;
```

`onTouchEvent`:

| Event | Behaviour |
|---|---|
| `DOWN` | Record `mDownX/Y`, `mCoverArmed = false`. Let super + `CheckLongPressHelper` run. |
| `MOVE` | If not armed: arm when `-dy > touchSlop && |dy| > |dx|`; then `getParent().requestDisallowInterceptTouchEvent(true)`, `cancelLongPress()`, `setPressed(false)`, haptic tick. If armed: update peek progress and consume. |
| `UP` | If armed: if `-dy >= COMMIT_DP` or velocity passes, `folder.animateOpen()`; else cancel. Reset. **Do not** forward to super after arming, or the click listener will fire and launch the face. |
| `CANCEL` | Reset; forward to super. |

`performLongClick()` override: cancel any cover gesture before delegating, so long-press always
wins and never opens the folder.

Parent interception: `requestDisallowInterceptTouchEvent(true)` on arm is required; the workspace
otherwise steals vertical drags for the drawer. Clear it on UP/CANCEL by resetting the flag on the
parent chain (or call `requestDisallowInterceptTouchEvent(false)`).

## 5. Peek and open animation

v1 (ship): arm at 24 dp, lift the icon by `-8 dp * progress`, scale `1 + 0.04 * progress`, fade a
40% scrim owned by the launcher, commit at 48 dp or 800 dp/s. On commit call `folder.animateOpen()`
— it already animates from the `FolderIcon` bounds, so the folder appears to grow out of the icon.

v1.1 (polish): the folder card follows the finger. Reuse `Folder.animateOpen()`'s open progress
and add a `peekProgress` setter; do not build a second folder surface. If this fights the existing
animation, cut it — the arm/commit version is already better than a plain tap.

Reduce motion: replace the lift/spring with a 120 ms cross-fade; keep the haptic.

## 6. Conversion and settings

v1 entry points:

1. **Auto-convert on creation** (setting, default on): when a new folder reaches 2+ apps, set
   `FLAG_COVER`. This makes the feature discoverable by doing nothing.
2. **Settings → Home screen → Covers** — a list of folders with switches (searchable), plus
   "Make all folders covers".
3. **Long-press menu** (v1.1): "Use as cover" / "Stop using cover" in `OptionsPopupView`.

Preferences (new `CoverPrefs`, `SharedPreferences` file `alcove_covers`; do not touch
`LauncherPrefs` in v1):

| Key | Default | Type |
|---|---|---|
| `enabled` | true | bool |
| `show_count` | true | bool |
| `haptic_peek` | true | bool |
| `swipe_direction` | `UP` | enum |
| `label_mode` | `APP` | enum |
| `auto_convert` | true | bool |

Listen for changes with `OnSharedPreferenceChangeListener` and reload the workspace (Lawnchair's
`ReloadHelper` does this for its own prefs; reuse it).

## 7. Files

**Core patches (keep each under ~30 lines):**

| File | Change |
|---|---|
| `src/com/android/launcher3/model/data/FolderInfo.java` | `FLAG_COVER`, `isCover`, `getCoverItem`, `setCover` |
| `src/com/android/launcher3/folder/FolderIcon.java` | cover branch in `dispatchDraw`, label policy, touch gesture, long-press cancel |
| `src/com/android/launcher3/folder/PreviewItemManager.java` | expose `getOrCreateDrawable(ItemInfo)` (or a public drawable cache accessor) |
| `src/com/android/launcher3/touch/ItemClickHandler.java` | cover branch in `onClickFolderIcon` |

**New files (ours, no rebase cost):**

```
lawnchair/src/app/alcove/covers/
  CoverPrefs.kt              # keys, defaults, listener
  CoverBadge.kt              # count pill paint/draw
  CoverStackDrawable.kt      # the 4 dp stacked edge
  CoverSettingsScreen.kt     # Compose preference destination
  CoverTutorial.kt           # one-time anchored tooltip
  CoverFolderListViewModel.kt
```

Resources: `strings.xml` (EN/DE), `dimens.xml` (`cover_stack_offset`, `cover_badge_size`),
`drawable/cover_stack.xml` if a shape drawable is enough.

## 8. Edge cases

| Case | Expected |
|---|---|
| Folder has 1 app | Not a cover; normal folder icon; if it was a cover, clear flag + undo snackbar |
| Folder is empty | Removed by Launcher3; clear flag first |
| Face app uninstalled | Loader removes the child; next child becomes face; icon updates |
| Face app disabled / suspended | `onClickAppShortcut` shows the existing disabled dialog; do not open folder |
| Face app archived | Cloud badge; tap triggers the system restore flow |
| Work profile face | Work badge must still render; launching crosses profile via the normal path |
| Folder has more than one page | Face is `contents.get(0)`; folder opens on page 0 |
| Hotseat folder | Gesture works; verify no conflict with hotseat drag |
| RTL | Badge mirrors; label truncation direction follows locale |
| Icon pack / themed icons | Face uses the same drawable pipeline as normal icons |
| Backup/restore | `OPTIONS` is copied; verify with a Lawnchair backup round-trip |
| Process death while folder open | Launcher restores state; cover flag is in the DB, nothing to restore |

## 9. Tests

Unit:

- `FolderInfoCoverTest`: flag set/clear persists through `ContentWriter`; `getCoverItem` ordering;
  removing the face promotes the next child.
- `CoverPrefsTest`: defaults, enum parsing, listener.

Instrumented (`LauncherActivityRule` + `UiController`):

- tap on cover launches face (assert intent/activity), not folder;
- swipe 30 dp does nothing; swipe 60 dp opens folder; horizontal swipe does not;
- long-press opens the menu, not the folder;
- drag moves the folder; drop adds to folder;
- rotate and process-death restore;
- TalkBack custom action opens the folder.

Manual matrix: see [PLAN.md](PLAN.md) §7.

## 10. Performance budget

- No new `Bitmap` decode per frame; the face drawable comes from the icon cache.
- `dispatchDraw` allocates nothing; stack/badge paints and rects are fields.
- Peek animation: only `translationY`/`scale`/`alpha` on the icon and scrim; no relayout.
- Folder open: existing `Folder.animateOpen` path; measure input-to-first-frame < 100 ms on the
  A54 (the slower device).

## 11. Open technical questions

1. Does Lawnchair's folder implementation differ from AOSP `main` in `FolderIcon`/`Folder` enough
   to invalidate the patch locations? Check `16-dev` before writing code; the classes exist but
   may have moved.
2. Can `OptionsPopupView` accept a new item without touching the core, or is the settings list the
   only low-risk conversion path for v1?
3. Does `FolderIcon` get rebound on icon-pack changes in a way that drops the cached face
   drawable? Plan a `rebind` hook.
4. Is the 4 dp stack edge enough to signal "folder" at 420 dpi, or does it need the count badge by
   default? Resolve with the first five testers.
