<#
.SYNOPSIS
    Build the Alcove fork and optionally install it on a connected device.

.DESCRIPTION
    Fast path for development: no git fetch, no merges. Use sync-upstream.ps1 to
    update from Lawnchair and carry the cover-mode PR.

.EXAMPLE
    .\scripts\build.ps1 -Install -Device RZGL81FQYEN -Launch
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Launch,
    [string]$Device = "",
    [string]$Task = "assembleLawnWithQuickstepGithubDebug"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $env:JAVA_HOME) {
    throw "JAVA_HOME is not set. Use JDK 21 or newer."
}
if (-not (Test-Path (Join-Path $root "local.properties"))) {
    throw "local.properties is missing. Create it with sdk.dir=<Android SDK path>."
}

if (-not $env:GRADLE_USER_HOME) {
    $env:GRADLE_USER_HOME = Join-Path $root ".tools\gradle-home"
}
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null

$logDir = Join-Path $root ".tools\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("build-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

$gradlew = Join-Path $root "gradlew.bat"
if (-not (Test-Path $gradlew)) { $gradlew = "gradle" }

Write-Host "building $Task ..." -ForegroundColor Cyan
& $gradlew --console=plain $Task 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -ne 0) {
    throw "Gradle failed. Log: $log"
}

$apk = Get-ChildItem (Join-Path $root "build\outputs\apk\lawnWithQuickstepGithub\debug") `
    -Filter *.apk -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $apk) { throw "No APK found under build\outputs\apk." }

Write-Host "APK: $($apk.FullName) ($([math]::Round($apk.Length / 1MB, 1)) MB)" -ForegroundColor Green
Write-Host "log: $log"

if ($Install) {
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) {
        $line = Get-Content (Join-Path $root "local.properties") |
            Where-Object { $_ -match "^sdk\.dir=" } | Select-Object -First 1
        if ($line) { $sdk = ($line -replace "^sdk\.dir=", "") -replace "\\:", ":" -replace "\\\\", "\" }
    }
    $adb = if ($sdk) { Join-Path $sdk "platform-tools\adb.exe" } else { "adb" }
    if (-not (Test-Path $adb)) { $adb = "adb" }

    if (-not $Device) {
        $online = @(& $adb devices | Select-String "`tdevice$")
        if ($online.Count -eq 1) {
            $Device = ($online[0].Line -split "`t")[0]
        } else {
            throw "Specify -Device. Online devices: $($online.Count)"
        }
    }

    Write-Host "installing on $Device ..."
    & $adb -s $Device install -r $apk.FullName
    if ($LASTEXITCODE -ne 0) { throw "adb install failed" }

    if ($Launch) {
        & $adb -s $Device shell am start -n app.lawnchair.debug/app.lawnchair.LawnchairLauncher | Out-Null
    }
}
