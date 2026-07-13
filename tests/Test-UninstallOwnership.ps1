$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "TskSkinSwap-uninstall-$([Guid]::NewGuid().ToString('N'))"

try {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repositoryRoot 'Uninstall-TskSkinSwap.ps1'),
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count) {
        throw 'Uninstall-TskSkinSwap.ps1 did not parse.'
    }
    foreach ($name in @('Get-OtherBepInExAddons', 'Test-LegacyTskBepInExInstall')) {
        $function = $ast.Find({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
        }, $true)
        Invoke-Expression $function.Extent.Text
    }

    $GamePath = Join-Path $testRoot 'game'
    $pluginDirectory = Join-Path $GamePath 'BepInEx\plugins\TskSkinSwap'
    $bepInExCore = Join-Path $GamePath 'BepInEx\core\BepInEx.Unity.IL2CPP.dll'
    $bepInExArchive = Join-Path $testRoot 'BepInEx.zip'
    New-Item -ItemType Directory -Force -Path (Split-Path $bepInExCore -Parent), $pluginDirectory | Out-Null
    Set-Content -LiteralPath $bepInExCore -Value 'test' -Encoding ASCII
    Set-Content -LiteralPath $bepInExArchive -Value 'verified installer archive' -Encoding ASCII
    $bepInExSha256 = (Get-FileHash -LiteralPath $bepInExArchive -Algorithm SHA256).Hash
    foreach ($name in @('.doorstop_version', 'doorstop_config.ini', 'winhttp.dll')) {
        Set-Content -LiteralPath (Join-Path $GamePath $name) -Value 'test' -Encoding ASCII
    }

    if (-not (Test-LegacyTskBepInExInstall)) {
        throw 'A valid legacy TskSkinSwap BepInEx installation was not detected.'
    }

    $otherAddon = Join-Path $GamePath 'BepInEx\plugins\Other\Other.dll'
    New-Item -ItemType Directory -Force -Path (Split-Path $otherAddon -Parent) | Out-Null
    Set-Content -LiteralPath $otherAddon -Value 'test' -Encoding ASCII
    if (Test-LegacyTskBepInExInstall) {
        throw 'An installation with another add-on was incorrectly claimed.'
    }

    Remove-Item -LiteralPath (Split-Path $otherAddon -Parent) -Recurse -Force
    Add-Content -LiteralPath $bepInExArchive -Value 'corrupt'
    if (Test-LegacyTskBepInExInstall) {
        throw 'An installation with an unverified installer archive was incorrectly claimed.'
    }

    Write-Host 'Uninstall ownership tests passed.'
} finally {
    if (Test-Path $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
