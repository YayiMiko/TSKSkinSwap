[CmdletBinding()]
param(
    [string[]]$CharacterId,
    [string]$SourceApk,
    [switch]$DryRun,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$toolRoot = $PSScriptRoot
$toolsRoot = Join-Path $toolRoot '.tools\android-installer'
$pythonRoot = Join-Path $toolsRoot 'python'
$pythonExe = Join-Path $pythonRoot 'python.exe'
$platformToolsRoot = Join-Path $toolsRoot 'platform-tools'
$adbExe = Join-Path $platformToolsRoot 'adb.exe'
$installer = Join-Path $toolRoot 'android\installer.py'
$apkSource = Join-Path $toolRoot 'android\apk_source.py'
$apkBuilder = Join-Path $toolRoot 'Build-TskSkinSwap-AndroidApk.ps1'
$apkCache = Join-Path $toolsRoot 'apk'
$releaseRuntime = Join-Path $toolRoot 'android\runtime\tskskinswap.js'
$developmentRuntime = Join-Path $toolRoot 'android\dist\tskskinswap.js'
$runtime = if (Test-Path $releaseRuntime) { $releaseRuntime } else { $developmentRuntime }

function Get-RemoteFile {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Write-Host "Downloading $Uri"
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination
}

New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null

if (-not (Test-Path $adbExe)) {
    $developmentAdb = Join-Path $toolRoot '.tools\android\platform-tools\adb.exe'
    $systemAdb = Get-Command adb.exe -ErrorAction SilentlyContinue
    if (Test-Path $developmentAdb) {
        $adbExe = $developmentAdb
    } elseif ($systemAdb) {
        $adbExe = $systemAdb.Source
    } else {
        $platformToolsZip = Join-Path $toolsRoot 'platform-tools-latest-windows.zip'
        if (-not (Test-Path $platformToolsZip)) {
            Get-RemoteFile `
                -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' `
                -Destination $platformToolsZip
        }
        Expand-Archive -LiteralPath $platformToolsZip -DestinationPath $toolsRoot -Force
    }
}

if (-not (Test-Path $pythonExe)) {
    $pythonZip = Join-Path $toolsRoot 'python-3.12.10-embed-amd64.zip'
    if (-not (Test-Path $pythonZip)) {
        Get-RemoteFile `
            -Uri 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip' `
            -Destination $pythonZip
    }
    New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
    Expand-Archive -LiteralPath $pythonZip -DestinationPath $pythonRoot -Force
}

if (-not (Test-Path $runtime)) {
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npm) {
        throw 'Compiled Android runtime is missing. Use a release package or install Node.js to build from source.'
    }
    Push-Location (Join-Path $toolRoot 'android')
    try {
        & $npm.Source install
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
        & $npm.Source run build
        if ($LASTEXITCODE -ne 0) { throw 'Android runtime build failed.' }
    } finally {
        Pop-Location
    }
}

if ((& $adbExe get-state 2>$null) -ne 'device') {
    throw 'No authorized Android device is connected. Unlock the phone and allow USB debugging.'
}
$devices = @(& $adbExe devices | Select-String -Pattern "\tdevice$")
if ($devices.Count -ne 1) {
    throw "Exactly one authorized Android device is required; found $($devices.Count)."
}
$package = 'jp.co.fanzagames.twinklestarknightsx_a_mod'
if (-not ((& $adbExe shell pm path $package 2>$null) -like 'package:*')) {
    throw 'Install and launch the compatible Android package (APK) once before applying this MOD.'
}
$catalog = "/sdcard/Android/data/$package/files/com.unity.addressables/catalog_0.0.0.json"
$catalogReady = & $adbExe shell "if [ -f '$catalog' ]; then echo READY; fi"
if ($catalogReady -ne 'READY') {
    throw 'Launch the game on the phone, finish its initial data download, close it, and run this BAT again.'
}

if (-not $DryRun) {
    if ($SourceApk) {
        $resolvedSourceApk = (Resolve-Path $SourceApk).Path
    } else {
        New-Item -ItemType Directory -Force -Path $apkCache | Out-Null
        & $pythonExe $apkSource --output-dir $apkCache | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Compatible APK download failed.' }
        $sourceMetadata = Get-Content -Raw -LiteralPath (Join-Path $apkCache 'source-apk.json') |
            ConvertFrom-Json
        if ($sourceMetadata.schemaVersion -ne 1 -or
            $sourceMetadata.assetName -notmatch '^Kurusuta-X\.Mod_[0-9.]+_patched\.apk$') {
            throw 'Compatible APK downloader returned invalid metadata.'
        }
        $resolvedSourceApk = Join-Path $apkCache $sourceMetadata.assetName
        if (-not (Test-Path $resolvedSourceApk)) {
            throw 'Compatible APK downloader did not return a valid file.'
        }
    }
    & $apkBuilder `
        -InputApk $resolvedSourceApk `
        -RuntimeScript $runtime `
        -SkipRuntimeBuild `
        -Install `
        -Adb $adbExe
    if ($LASTEXITCODE -ne 0) { throw 'Compatible APK patching or installation failed.' }
}

$arguments = @(
    $installer,
    '--adb', $adbExe,
    '--embedded-runtime',
    '--output-dir', (Join-Path $toolRoot 'downloaded\android')
)
foreach ($id in $CharacterId) {
    $arguments += @('--character-id', $id)
}
if ($DryRun) { $arguments += '--dry-run' }
if ($NoRestart) { $arguments += '--no-restart' }

& $pythonExe @arguments
exit $LASTEXITCODE
