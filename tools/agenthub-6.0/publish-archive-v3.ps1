# AgentHub 6.0 package publisher - v3
# Download this uniquely named script to avoid cached older revisions.
# irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/publish-archive-v3.ps1 -OutFile "$env:TEMP\publish-agenthub6-v3.ps1"
# & "$env:TEMP\publish-agenthub6-v3.ps1" -ZipPath "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"

param(
    [string]$ZipPath = "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"
)

$ErrorActionPreference = 'Stop'
$expectedSha256 = '15064252d36e2da68b4301190ebe645a57ba6ad13318a04be7c097f6f051ce25'
$repoUrl = 'https://github.com/sonox99/HP3RC2.git'
$relativeDir = 'tools\agenthub-6.0'
$repoRoot = Join-Path ([IO.Path]::GetTempPath()) ("HP3RC2-AgentHub6-v3-" + [guid]::NewGuid().ToString('N'))
$targetDir = Join-Path $repoRoot $relativeDir
$targetZip = Join-Path $targetDir 'PS2RC-AgentHub-6.0-Clean.zip'

Write-Host 'AgentHub 6.0 Publisher v3' -ForegroundColor Cyan
if (!(Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "ZIP nicht gefunden: $ZipPath" }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git ist nicht installiert oder nicht im PATH.' }

$actualSha256 = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Lokaler SHA-256: $actualSha256"
if ($actualSha256 -ne $expectedSha256) {
    throw "Falsches Paket. Erwartet: $expectedSha256; erhalten: $actualSha256"
}
Write-Host 'SHA-256 stimmt. Starte GitHub-Publish ...' -ForegroundColor Green

try {
    git clone --branch main $repoUrl $repoRoot
    if ($LASTEXITCODE -ne 0) { throw 'git clone fehlgeschlagen.' }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -LiteralPath $ZipPath -Destination $targetZip -Force

    $copiedHash = (Get-FileHash -LiteralPath $targetZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copiedHash -ne $expectedSha256) { throw "Kopie stimmt nicht: $copiedHash" }

    Push-Location $repoRoot
    try {
        git add -- $relativeDir
        if ($LASTEXITCODE -ne 0) { throw 'git add fehlgeschlagen.' }

        git -c user.name='AgentHub Publisher' -c user.email='agenthub-publisher@users.noreply.github.com' commit -m 'Publish AgentHub 6.0 Clean ZIP'
        if ($LASTEXITCODE -ne 0) { throw 'git commit fehlgeschlagen.' }

        git push origin main
        if ($LASTEXITCODE -ne 0) { throw 'git push fehlgeschlagen. GitHub-Anmeldung oder Branch-Schutz pruefen.' }
    }
    finally { Pop-Location }

    Write-Host ''
    Write-Host 'AgentHub 6.0 ZIP erfolgreich auf GitHub veroeffentlicht.' -ForegroundColor Green
    Write-Host "Repo-Pfad: $relativeDir/PS2RC-AgentHub-6.0-Clean.zip"
    Write-Host "SHA-256: $expectedSha256"
    Write-Host 'Danach installieren mit:'
    Write-Host 'irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex'
}
finally {
    if (Test-Path -LiteralPath $repoRoot) { Remove-Item -LiteralPath $repoRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
