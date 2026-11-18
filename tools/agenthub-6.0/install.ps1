# AgentHub 6.0 bootstrap installer
# Usage: irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$archiveUrl = 'https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/PS2RC-AgentHub-6.0-Clean.zip'
$expectedSha256 = '7330b9c47e4c5ca894ee0422fbd5a206067fc8611e9bf79b8ee8d28803761072'
$installRoot = $env:AGENTHUB6_INSTALL_ROOT
if ([string]::IsNullOrWhiteSpace($installRoot)) { $installRoot = 'F:\AI\PS2RC-AgentHub-6.0' }
if (Test-Path -LiteralPath $installRoot) { throw "Zielordner existiert bereits und wird nicht ueberschrieben: $installRoot" }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("AgentHub6-" + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempRoot 'PS2RC-AgentHub-6.0-Clean.zip'
$extractRoot = Join-Path $tempRoot 'extract'
try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-Host 'Lade AgentHub 6.0 Clean ...'
    Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
    $actualSha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $expectedSha256) { throw "SHA-256-Pruefung fehlgeschlagen: $actualSha256" }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $sourceRoot = Join-Path $extractRoot 'PS2RC-AgentHub-6.0'
    if (!(Test-Path -LiteralPath (Join-Path $sourceRoot 'START-AGENTHUB.bat'))) { throw 'Archivstruktur ungueltig.' }
    $parent = Split-Path -Parent $installRoot
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Move-Item -LiteralPath $sourceRoot -Destination $installRoot
    Write-Host "AgentHub 6.0 installiert: $installRoot" -ForegroundColor Green
    Write-Host 'Vor dem Start agenthub.env.example nach .env kopieren und die lokalen Ollama-Endpunkte pruefen.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
