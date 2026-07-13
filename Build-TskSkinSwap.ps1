[CmdletBinding()]
param(
    [string]$GamePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'src\TskSkinSwap.csproj'
$interop = Join-Path $GamePath 'BepInEx\interop'
$core = Join-Path $GamePath 'BepInEx\core'

if (-not (Test-Path $interop)) {
    throw 'BepInEx interop assemblies are missing. Start the game once after installing BepInEx.'
}

$env:TSK_GAME_DIR = $GamePath
$localDotnet = Join-Path $PSScriptRoot '.tools\dotnet\dotnet.exe'
$dotnet = if (Test-Path $localDotnet) { $localDotnet } else { 'dotnet' }
& $dotnet build $project -c Release
if ($LASTEXITCODE -ne 0) {
    throw "Plugin build failed with exit code $LASTEXITCODE"
}

if (-not $SkipInstall) {
    $pluginDir = Join-Path $GamePath 'BepInEx\plugins\TskSkinSwap'
    New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'src\bin\Release\net6.0\TskSkinSwap.dll') $pluginDir -Force
    Write-Host "Installed plugin: $(Join-Path $pluginDir 'TskSkinSwap.dll')"
}
