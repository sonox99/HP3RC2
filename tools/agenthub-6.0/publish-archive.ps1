param(
    [string]$ZipPath = "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"
)

$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/sonox99/HP3RC2.git'
$repoRoot = Join-Path ([IO.Path]::GetTempPath()) ("HP3RC2-AgentHub6-" + [guid]::NewGuid().ToString('N'))
$relativeDir = 'tools\agenthub-6.0'
$targetDir = Join-Path $repoRoot $relativeDir
$targetZip = Join-Path $targetDir 'PS2RC-AgentHub-6.0-Clean.zip'
$expectedSha256 = '15064252d36e2da68b4301190ebe645a57ba6ad13318a04be7c097f6f051ce25'

if (!(Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "ZIP nicht gefunden: $ZipPath" }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git ist nicht installiert oder nicht im PATH.' }

try {
    $localHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($localHash -ne $expectedSha256) {
        throw "Falsches AgentHub-6.0-Paket. Erwartet: $expectedSha256; erhalten: $localHash"
    }

    git clone --branch main $repoUrl $repoRoot
    if ($LASTEXITCODE -ne 0) { throw 'Git clone fehlgeschlagen. GitHub-Anmeldung in Git Credential Manager pruefen.' }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -LiteralPath $ZipPath -Destination $targetZip

    $copiedHash = (Get-FileHash -LiteralPath $targetZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copiedHash -ne $expectedSha256) { throw "Pruefung der kopierten ZIP fehlgeschlagen: $copiedHash" }

    Push-Location $repoRoot
    try {
        git add -- $relativeDir
        if ($LASTEXITCODE -ne 0) { throw 'git add fehlgeschlagen.' }

        git -c user.name='AgentHub Publisher' -c user.email='agenthub-publisher@users.noreply.github.com' commit -m 'Add AgentHub 6.0 Clean package'
        if ($LASTEXITCODE -ne 0) { throw 'git commit fehlgeschlagen.' }

        git push origin main
        if ($LASTEXITCODE -ne 0) { throw 'git push fehlgeschlagen. GitHub-Rechte/Branch-Schutz pruefen.' }
    }
    finally { Pop-Location }

    Write-Host 'AgentHub 6.0 ZIP wurde zu HP3RC2 hochgeladen.' -ForegroundColor Green
    Write-Host "SHA-256: $expectedSha256"
    Write-Host 'Installer: irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex'
}
finally {
    if (Test-Path -LiteralPath $repoRoot) { Remove-Item -LiteralPath $repoRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
