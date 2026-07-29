$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$EngineRoot = Join-Path $ProjectRoot ".kristal-engine"
$ModId = "deltarune_from_scratch_ch1"
$ModLink = Join-Path (Join-Path $EngineRoot "mods") $ModId

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required. Install Git for Windows, then run this script again."
}

if (-not (Test-Path $EngineRoot)) {
    Write-Host "Cloning Kristal..."
    git clone --depth 1 https://github.com/KristalTeam/Kristal.git $EngineRoot
    if ($LASTEXITCODE -ne 0) { throw "Kristal clone failed." }
} else {
    Write-Host "Updating Kristal..."
    git -C $EngineRoot pull --ff-only
}

New-Item -ItemType Directory -Force -Path (Join-Path $EngineRoot "mods") | Out-Null

if (Test-Path $ModLink) {
    $Existing = Get-Item -Force $ModLink
    if ($Existing.FullName -ne $ProjectRoot) {
        Remove-Item -Recurse -Force $ModLink
    }
}

if (-not (Test-Path $ModLink)) {
    New-Item -ItemType Junction -Path $ModLink -Target $ProjectRoot | Out-Null
}

$Love = (Get-Command love -ErrorAction SilentlyContinue).Source
if (-not $Love) {
    $Candidates = @(
        (Join-Path $env:ProgramFiles "LOVE\love.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "LOVE\love.exe")
    )
    $Love = $Candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $Love) {
    throw "LÖVE was not found. Install LÖVE 11.x or add love.exe to PATH."
}

Write-Host "Launching the real Kristal battle engine..."
& $Love $EngineRoot --mod $ModId
