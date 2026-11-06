# Upstream policy

The fork has one job: **be the newest working Lawnchair 16 with cover mode**. This document defines
what "newest", "working" and "cover mode" mean in practice, and how the repo recovers when an
update breaks.

## Branches and remotes

| Ref | Meaning |
|---|---|
| `upstream` | `https://github.com/LawnchairLauncher/lawnchair.git` |
| `origin` | our fork (add when a GitHub/GitLab repo exists; not configured yet) |
| `main` | `upstream/16-dev` + Alcove docs/scripts + the cover-mode merge |
| `pr/7213` | local mirror of `refs/pull/7213/head`, fetched by the sync script |
| `docs-v1` | the original docs-only commit (`fbc4f3a`), kept for history |
| `alcove-last-good` | tag on the last commit that built successfully |
| `alcove-failed-*` | local branches kept when a sync/build fails, for inspection |

`main` deliberately contains upstream history, so the repo can be pushed as a real GitHub fork
later without rewriting anything.

## The sync loop

```powershell
.\scripts\sync-upstream.ps1 -Install -Device RZGL81FQYEN
```

1. **Clean check.** Refuses to run with a dirty working tree; `local.properties`, `.tools/` and
   build outputs are ignored.
2. **Fetch.** `git fetch --no-tags upstream 16-dev` and, if needed,
   `git fetch upstream refs/pull/7213/head:refs/heads/pr/7213`.
3. **Upstream merge.** If `upstream/16-dev` is not an ancestor of `HEAD`, merge it with
   `--no-ff`. A conflict on `README.md` is resolved in favour of the fork (our README is
   intentional); any other conflict aborts and rolls back.
4. **Cover detection.** `git grep -qiE "FLAG_COVER|FolderCoverMode|cover[_ -]mode" upstream/16-dev -- src lawnchair`.
   If it matches, upstream already ships cover mode and the PR is not merged. This is the switch
   that makes the fork self-cleaning when the PR lands.
5. **PR merge.** If cover mode is missing, fetch and merge `pr/7213`. If the PR head advanced,
   only the new commits are merged.
6. **Build.** `assembleLawnWithQuickstepGithubDebug` with the repo-local
   `GRADLE_USER_HOME` and the wrapper.
7. **Success.** Tag `alcove-last-good`, print the APK, optionally `adb install -r` and launch.
8. **Failure.** If a merge completed but the build failed, keep that commit as
   `alcove-failed-<timestamp>` for inspection. If a merge conflicted, abort it. Either way,
   `git reset --hard` back to the starting commit, so the previous good version is never left
   half-updated.

`-NoBuild` stops after the merge (useful to inspect a conflict-free update before committing to a
build). `-NoPr` ignores the PR (useful if upstream has an implementation the detector does not
recognise).

## What "newest working" means

- **Newest:** `upstream/16-dev` at the time the script runs. It does not track `main`, tags or
  release branches on purpose — `16-dev` is where Lawnchair 16 development happens. When
  Lawnchair opens `17-dev`, run with `-UpstreamBranch 17-dev`; everything else stays the same.
- **Working:** the debug variant assembles and the APK installs/launches. The script does not run
  the instrumented suite yet; that is a follow-up (`scripts/test.ps1`) before the fork is used as
  a daily driver.
- **Cover mode:** detected by source, not by PR state. If upstream implements it differently, the
  detector may need a new pattern; `-NoPr` plus a manual check is the escape hatch.

## Lifecycle of PR #7213

| Event | What happens |
|---|---|
| PR gets new commits | Next sync fetches the new head and merges only the delta |
| PR is merged into `16-dev` | Detector finds cover mode; PR merge is skipped. If the merge was a real merge, our earlier merge already contains the commits and the upstream merge is trivial. If it was squashed, resolve the expected conflict in the cover files in favour of upstream, then delete `pr/7213` |
| PR is closed without merging | Sync keeps merging the last head. Decide whether to keep carrying it or move the feature into `lawnchair/src/app/alcove/` as fork-owned code |
| PR branch is deleted | `git fetch refs/pull/7213/head` fails, sync stops and rolls back; the last good commit still has the feature |

When the PR is merged upstream, no history rewrite is needed. `main` keeps the merge commit; the
only follow-up is to delete the local `pr/7213` branch and remove the PR from this document.

## Conflicts

Expected conflict zones, in order of likelihood:

1. `README.md` — auto-resolved to ours by the script.
2. `src/com/android/launcher3/folder/FolderIcon.java`, `Workspace.java`, `Hotseat.java`,
   `PortraitStatesTouchController.java`, `ItemClickHandler.java` — upstream refactors in these
   files can collide with the PR. Resolve by keeping upstream's structure and re-applying the
   cover hooks; build before committing.
3. `lawnchair/res/values/strings.xml` — string additions usually auto-merge; if not, keep both.

To resolve manually:

```powershell
# inspect the failed state
git switch alcove-failed-<timestamp>
# resolve, build, then bring the result onto main
.\scripts\build.ps1
```

## Version pins

- JDK 21+ (CI uses 21; this host builds with 25).
- Gradle 9.8.2 via the wrapper.
- AGP 9.5.x from `gradle/libs.versions.toml`.
- SDK platform 37.2, build-tools 37.0.0. If `sdkmanager` refuses 37.2, install it manually:
  `https://dl.google.com/android/repository/platform-37.2_r02.zip` unpacked into
  `%LOCALAPPDATA%\Android\Sdk\platforms\android-37.2` (see [BUILD.md](BUILD.md)).

## Remotes and publishing

The fork lives at <https://github.com/L3v1a7h4N/lawnchair>:

```powershell
origin    https://github.com/L3v1a7h4N/lawnchair.git
upstream  https://github.com/LawnchairLauncher/lawnchair.git
```

`main` tracks `origin/main`. Push normal changes with:

```powershell
git push
```

The first push also published the `alcove-*` tags. Do not push `pr/7213` or `alcove-failed-*`;
they are local working refs.

**Default branch:** the GitHub fork was created with upstream's `16-dev` as its default. Set it to
`main` once, in *Settings → General → Default branch*, so the repository page shows Alcove rather
than upstream's branch. This is a server-side setting; `git push` cannot change it.

The fork still shows "forked from LawnchairLauncher/lawnchair", which is accurate: `main` contains
upstream history, the Alcove docs and the PR #7213 merge.
