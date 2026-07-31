[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $Root "build"
$ReleaseOut = Join-Path $BuildDir "release"
$DebugOut = Join-Path $BuildDir "debug"
$ReleaseStage = Join-Path $env:TEMP ("delta-scratch-release-" + [Guid]::NewGuid().ToString("N"))
$DebugStage = Join-Path $env:TEMP ("delta-scratch-debug-" + [Guid]::NewGuid().ToString("N"))
$BootExe = Join-Path $env:TEMP ("delta-scratch-love-" + [Guid]::NewGuid().ToString("N") + ".exe")
$BuildSucceeded = $false

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=== " + $Text + " ===") -ForegroundColor Cyan
}

function Require-RepoPath {
    param([string]$RelativePath, [string]$Description)

    $fullPath = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Missing $Description at: $fullPath"
    }
}

function Assert-OutputFile {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not created at: $Path"
    }
    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "$Description is empty at: $Path"
    }
}

function New-CleanDirectory {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-GameTree {
    param([string]$Destination)

    New-CleanDirectory -Path $Destination
    Copy-Item -LiteralPath (Join-Path $Root "main.lua") -Destination (Join-Path $Destination "main.lua") -Force
    Copy-Item -LiteralPath (Join-Path $Root "conf.lua") -Destination (Join-Path $Destination "conf.lua") -Force

    $notices = Join-Path $Root "THIRD_PARTY_NOTICES.md"
    if (Test-Path -LiteralPath $notices) {
        Copy-Item -LiteralPath $notices -Destination (Join-Path $Destination "THIRD_PARTY_NOTICES.md") -Force
    }

    foreach ($directory in @("src", "vendor", "assets")) {
        Copy-Item -LiteralPath (Join-Path $Root $directory) -Destination (Join-Path $Destination $directory) -Recurse -Force
    }
}

function Assert-LovePackageLayout {
    param([string]$PackagePath)

    $requiredEntries = @(
        "main.lua",
        "conf.lua",
        "src/game.lua",
        "vendor/kristal_legacy/battle.lua",
        "assets/fonts/DeterminationMonoWebRegular-Z5oq.ttf"
    )

    $archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($requiredEntry in $requiredEntries) {
            if ($entryNames -notcontains $requiredEntry) {
                throw "LOVE package has an invalid archive root. Missing entry: $requiredEntry"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function New-LovePackage {
    param([string]$StageDirectory, [string]$OutputFile)

    if (Test-Path -LiteralPath $OutputFile) {
        Remove-Item -LiteralPath $OutputFile -Force
    }

    # Resolve both roots before calculating relative paths. Using the raw TEMP
    # string previously left part of the random directory name inside the ZIP,
    # producing entries such as "77a/main.lua" instead of root-level main.lua.
    $stageRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $StageDirectory).Path)
    $stageRoot = $stageRoot.TrimEnd([char[]]@([char]92, [char]47)) + [IO.Path]::DirectorySeparatorChar
    $files = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File)
    if ($files.Count -eq 0) {
        throw "No files were staged for: $OutputFile"
    }

    $outputStream = [IO.File]::Open($OutputFile, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try {
        $archive = New-Object IO.Compression.ZipArchive(
            $outputStream,
            [IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($file in $files) {
                $fullFilePath = [IO.Path]::GetFullPath($file.FullName)
                if (-not $fullFilePath.StartsWith($stageRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "Staged file escaped the package root: $fullFilePath"
                }

                $relativePath = $fullFilePath.Substring($stageRoot.Length)
                $entryName = $relativePath.Replace([char]92, [char]47)
                if ([string]::IsNullOrWhiteSpace($entryName)) {
                    throw "Could not calculate a ZIP entry name for: $fullFilePath"
                }

                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive,
                    $fullFilePath,
                    $entryName,
                    [IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $outputStream.Dispose()
    }

    Assert-OutputFile -Path $OutputFile -Description "LOVE package"
    Assert-LovePackageLayout -PackagePath $OutputFile
}

function Find-LoveExecutable {
    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:LOVE_EXE) {
        $candidates.Add($env:LOVE_EXE)
    }

    $programFiles64 = [Environment]::GetFolderPath("ProgramFiles")
    $programFiles32 = [Environment]::GetFolderPath("ProgramFilesX86")
    if ($programFiles64) { $candidates.Add((Join-Path $programFiles64 "LOVE\love.exe")) }
    if ($programFiles32) { $candidates.Add((Join-Path $programFiles32 "LOVE\love.exe")) }
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA "Programs\LOVE\love.exe"))
        $candidates.Add((Join-Path $env:LOCALAPPDATA "LOVE\love.exe"))
    }

    $pathCommand = Get-Command "love.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pathCommand) { $candidates.Add($pathCommand.Source) }
    $candidates.Add((Join-Path $Root "DeltaruneBuild\deltarune.exe"))

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Join-BinaryFiles {
    param([string]$FirstFile, [string]$SecondFile, [string]$OutputFile)

    $output = [IO.File]::Open($OutputFile, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try {
        foreach ($inputPath in @($FirstFile, $SecondFile)) {
            $input = [IO.File]::OpenRead($inputPath)
            try { $input.CopyTo($output) }
            finally { $input.Dispose() }
        }
    }
    finally {
        $output.Dispose()
    }
    Assert-OutputFile -Path $OutputFile -Description "Fused executable"
}

function Copy-LoveRuntime {
    param([string]$LoveDirectory, [string]$Destination)

    $dlls = @(Get-ChildItem -LiteralPath $LoveDirectory -Filter "*.dll" -File -ErrorAction SilentlyContinue)
    foreach ($dll in $dlls) {
        Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $Destination $dll.Name) -Force
    }

    $license = Join-Path $LoveDirectory "license.txt"
    if (Test-Path -LiteralPath $license) {
        Copy-Item -LiteralPath $license -Destination (Join-Path $Destination "LOVE-LICENSE.txt") -Force
    }
    return $dlls.Count
}

try {
    Set-Location -LiteralPath $Root

    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "       DELTA SCRATCH BUILD SYSTEM" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta

    foreach ($required in @(
        @{ Path = "main.lua"; Description = "main.lua" },
        @{ Path = "conf.lua"; Description = "conf.lua" },
        @{ Path = "src\game.lua"; Description = "game code" },
        @{ Path = "vendor\kristal_legacy\battle.lua"; Description = "Kristal-derived battle runtime" },
        @{ Path = "assets\fonts\DeterminationMonoWebRegular-Z5oq.ttf"; Description = "Determination Mono font" },
        @{ Path = "assets\fonts\DeterminationSansWebRegular-369X.ttf"; Description = "Determination Sans font" },
        @{ Path = "assets\ui\title-logo.png"; Description = "title logo" }
    )) {
        Require-RepoPath -RelativePath $required.Path -Description $required.Description
    }

    $loveExe = Find-LoveExecutable
    if ($loveExe) {
        Write-Host "Found LOVE runtime:" -ForegroundColor Green
        Write-Host ("  " + $loveExe)
    }
    else {
        Write-Warning "LOVE was not found automatically. The .love packages will still be built, but fused .exe files will be skipped."
    }

    Write-Section "Cleaning old output"
    New-CleanDirectory -Path $BuildDir
    New-Item -ItemType Directory -Path $ReleaseOut -Force | Out-Null
    New-Item -ItemType Directory -Path $DebugOut -Force | Out-Null

    Write-Section "Staging release files"
    Copy-GameTree -Destination $ReleaseStage

    Write-Section "Staging debug files"
    Copy-GameTree -Destination $DebugStage
    $debugConf = Join-Path $DebugStage "conf.lua"
    $debugText = [IO.File]::ReadAllText($debugConf) -replace "t\.console = false", "t.console = true"
    [IO.File]::WriteAllText($debugConf, $debugText, (New-Object Text.UTF8Encoding($false)))

    $releaseLove = Join-Path $ReleaseOut "deltarune.love"
    $debugLove = Join-Path $DebugOut "debug-deltarune.love"

    Write-Section "Building release .love"
    New-LovePackage -StageDirectory $ReleaseStage -OutputFile $releaseLove

    Write-Section "Building debug .love"
    New-LovePackage -StageDirectory $DebugStage -OutputFile $debugLove

    $builtExe = $false
    if ($loveExe) {
        $loveDirectory = Split-Path -Parent $loveExe
        Copy-Item -LiteralPath $loveExe -Destination $BootExe -Force
        $releaseExe = Join-Path $ReleaseOut "deltarune.exe"
        $debugExe = Join-Path $DebugOut "debug-deltarune.exe"

        Write-Section "Fusing release executable"
        Join-BinaryFiles -FirstFile $BootExe -SecondFile $releaseLove -OutputFile $releaseExe

        Write-Section "Fusing debug executable"
        Join-BinaryFiles -FirstFile $BootExe -SecondFile $debugLove -OutputFile $debugExe

        $releaseDllCount = Copy-LoveRuntime -LoveDirectory $loveDirectory -Destination $ReleaseOut
        $debugDllCount = Copy-LoveRuntime -LoveDirectory $loveDirectory -Destination $DebugOut
        Write-Host "Copied $releaseDllCount LOVE runtime DLLs into the release folder."
        Write-Host "Copied $debugDllCount LOVE runtime DLLs into the debug folder."
        if ($releaseDllCount -eq 0) {
            Write-Warning "No LOVE DLLs were found beside love.exe. The fused EXE may need LOVE to remain installed."
        }
        $builtExe = $true
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Release package:"
    Write-Host ("  " + $releaseLove)
    if ($builtExe) { Write-Host ("  " + (Join-Path $ReleaseOut "deltarune.exe")) }
    Write-Host "Debug package:"
    Write-Host ("  " + $debugLove)
    if ($builtExe) { Write-Host ("  " + (Join-Path $DebugOut "debug-deltarune.exe")) }

    $BuildSucceeded = $true
}
catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkRed
    }
}
finally {
    foreach ($temporaryPath in @($ReleaseStage, $DebugStage, $BootExe)) {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($BuildSucceeded) { exit 0 }
exit 1
