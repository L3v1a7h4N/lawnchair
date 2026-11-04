<#
.SYNOPSIS
    Bring the Alcove fork up to the newest Lawnchair 16-dev and make sure cover mode is present.

.DESCRIPTION
    The fork tracks LawnchairLauncher/lawnchair@16-dev. Cover mode currently lives in
    PR #7213, so this script:

      1. fetches upstream 16-dev and the PR head;
      2. merges upstream 16-dev into the current branch;
      3. merges the PR only while upstream does not already contain cover mode;
      4. builds the debug APK;
      5. tags the result alcove-last-good and, optionally, installs it.

    If anything fails, the branch is reset to the commit it started from, so the
    working tree always stays on a known-good version. The failed attempt is kept
    as a local branch (alcove-failed-*) for inspection.

.PARAMETER Install
    Install the built APK on a connected device with adb.

.PARAMETER Launch
    After installing, start the launcher activity (does not change the default home app).

.PARAMETER Device
    adb serial. Required when more than one device is connected.

.PARAMETER NoBuild
    Merge only, skip the Gradle build and the success tag.

.PARAMETER NoPr
    Never merge the cover PR (useful when upstream has its own implementation).

.PARAMETER Pr
    Pull request number to track. Defaults to 7213.

.PARAMETER BuildTask
    Gradle task. Defaults to assembleLawnWithQuickstepGithubDebug.

.EXAMPLE
    .\scripts\sync-upstream.ps1 -Install -Device RZGL81FQYEN
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Launch,
    [string]$Device = "",
    [switch]$NoBuild,
    [switch]$NoPr,
    [int]$Pr = 7213,
    [string]$BuildTask = "assembleLawnWithQuickstepGithubDebug"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$upstreamUrl = "https://github.com/LawnchairLauncher/lawnchair.git"
$upstreamRef = "upstream/16-dev"
$prRef = "pr/$Pr"
$logDir = Join-Path $root ".tools\logs"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$buildLog = Join-Path $logDir "build-$stamp.log"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-CoverMode {
    param([Parameter(Mandatory)][string]$Ref)
    # The PR names the flag FLAG_COVER_MODE and the helper FolderCoverMode. Match either,
    # so the check keeps working if upstream renames one of them.
    & git grep -qiE "FLAG_COVER|FolderCoverMode|cover[_ -]mode" $Ref -- src lawnchair 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Merge-Ref {
    param([Parameter(Mandatory)][string]$Ref)
    & git merge --no-ff --no-edit $Ref
    if ($LASTEXITCODE -eq 0) { return }

    $conflicts = @(& git diff --name-only --diff-filter=U)
    # README.md is ours by design; an upstream README edit must not block an update.
    $onlyReadme = $conflicts.Count -gt 0 -and
        (@($conflicts | Where-Object { $_ -ne "README.md" }).Count -eq 0)
    if ($onlyReadme) {
        Write-Warning "README.md conflicted; keeping the fork's README."
        Invoke-Git @("checkout", "--ours", "--", "README.md")
        Invoke-Git @("add", "README.md")
        Invoke-Git @("commit", "--no-edit")
        return
    }

    throw "Merge of $Ref conflicted in: $($conflicts -join ', ')"
}

Write-Host "Alcove sync — $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan

$dirty = @(& git status --porcelain)
if ($dirty.Count -gt 0) {
    throw "Working tree is not clean. Commit or stash first:`n$($dirty -join "`n")"
}

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "branch: $branch"

$remotes = @(& git remote)
if ($remotes -notcontains "upstream") {
    Write-Host "adding upstream remote"
    Invoke-Git @("remote", "add", "upstream", $upstreamUrl)
}

Write-Host "fetching $upstreamRef ..."
Invoke-Git @("fetch", "--no-tags", "upstream", "16-dev")

$startCommit = (& git rev-parse HEAD).Trim()
$upstreamCommit = (& git rev-parse $upstreamRef).Trim()
$coverInUpstream = Test-CoverMode $upstreamRef
$mergedUpstream = $false
$mergedPr = $false
$prCommit = $null

Write-Host "upstream: $($upstreamCommit.Substring(0, 10))"
Write-Host "cover mode already upstream: $coverInUpstream"

try {
    & git merge-base --is-ancestor $upstreamRef HEAD
    if ($LASTEXITCODE -ne 0) {
        Write-Host "merging upstream 16-dev ..."
        Merge-Ref $upstreamRef
        $mergedUpstream = $true
    } else {
        Write-Host "already contains upstream 16-dev"
    }

    if (-not $coverInUpstream -and -not $NoPr) {
        Write-Host "fetching PR #$Pr ..."
        Invoke-Git @("fetch", "--no-tags", "upstream", "refs/pull/$Pr/head:refs/heads/$prRef")
        $prCommit = (& git rev-parse $prRef).Trim()
        Write-Host "PR #$Pr head: $($prCommit.Substring(0, 10))"

        & git merge-base --is-ancestor $prRef HEAD
        if ($LASTEXITCODE -ne 0) {
            Write-Host "merging PR #$Pr ..."
            Merge-Ref $prRef
            $mergedPr = $true
        } else {
            Write-Host "PR #$Pr already merged"
        }
    } elseif ($coverInUpstream) {
        Write-Host "upstream ships cover mode; not merging PR #$Pr" -ForegroundColor Green
    }

    if ($NoBuild) {
        Write-Host "NoBuild set; stopping after merge." -ForegroundColor Yellow
        exit 0
    }

    if (-not (Test-Path (Join-Path $root "local.properties"))) {
        throw "local.properties is missing. Create it with sdk.dir=<Android SDK path>."
    }
    if (-not $env:JAVA_HOME) {
        throw "JAVA_HOME is not set. Use JDK 21 or newer."
    }

    if (-not $env:GRADLE_USER_HOME) {
        $env:GRADLE_USER_HOME = Join-Path $root ".tools\gradle-home"
    }
    New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null

    $gradlew = Join-Path $root "gradlew.bat"
    if (-not (Test-Path $gradlew)) { $gradlew = "gradle" }

    Write-Host "building $BuildTask ..." -ForegroundColor Cyan
    & $gradlew --console=plain $BuildTask 2>&1 | Tee-Object -FilePath $buildLog
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle failed. Log: $buildLog"
    }

    $apk = Get-ChildItem (Join-Path $root "build\outputs\apk\lawnWithQuickstepGithub\debug") `
        -Filter *.apk -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    Invoke-Git @("tag", "-f", "alcove-last-good", "HEAD")
    Invoke-Git @("tag", "-f", "alcove-good-$stamp", "HEAD")

    Write-Host ""
    Write-Host "OK — $branch is on $((& git rev-parse --short HEAD).Trim())" -ForegroundColor Green
    Write-Host "  upstream merged: $mergedUpstream"
    Write-Host "  PR #$Pr merged:  $mergedPr"
    if ($apk) { Write-Host "  APK: $($apk.FullName) ($([math]::Round($apk.Length / 1MB, 1)) MB)" }
    Write-Host "  build log: $buildLog"

    if ($Install) {
        $adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
        if (-not (Test-Path $adb)) { $adb = "adb" }

        if (-not $Device) {
            $online = @(& $adb devices | Select-String "`tdevice$")
            if ($online.Count -eq 1) {
                $Device = ($online[0].Line -split "`t")[0]
            } else {
                throw "Specify -Device. Online devices: $($online.Count)"
            }
        }
        if (-not $apk) { throw "No APK found to install." }

        Write-Host "installing on $Device ..."
        & $adb -s $Device install -r $apk.FullName
        if ($LASTEXITCODE -ne 0) { throw "adb install failed" }

        if ($Launch) {
            & $adb -s $Device shell am start -n app.lawnchair.debug/app.lawnchair.LawnchairLauncher | Out-Null
        }
    }
} catch {
    Write-Warning $_.Exception.Message

    $failedBranch = "alcove-failed-$stamp"
    & git branch -f $failedBranch HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "failed state kept as branch $failedBranch"
    }

    if (Test-Path (Join-Path $root ".git\MERGE_HEAD")) {
        & git merge --abort 2>$null
    }
    & git reset --hard $startCommit | Out-Null
    Write-Warning "rolled back to $($startCommit.Substring(0, 10))"
    exit 1
}
