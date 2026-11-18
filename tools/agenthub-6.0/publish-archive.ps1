param(
    [string]$ZipPath = "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"
)

$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/sonox99/HP3RC2.git'
$repoRoot = Join-Path ([IO.Path]::GetTempPath()) ("HP3RC2-AgentHub6-" + [guid]::NewGuid().ToString('N'))
$relativeDir = 'tools\agenthub-6.0'
$targetDir = Join-Path $repoRoot $relativeDir
$targetZip = Join-Path $targetDir 'PS2RC-AgentHub-6.0-Clean.zip'

if (!(Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "ZIP nicht gefunden: $ZipPath" }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git ist nicht installiert oder nicht im PATH.' }

try {
    git clone --branch main $repoUrl $repoRoot
    if ($LASTEXITCODE -ne 0) { throw 'Git clone fehlgeschlagen. GitHub-Anmeldung in Git Credential Manager pruefen.' }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -LiteralPath $ZipPath -Destination $targetZip
    $hash = (Get-FileHash -LiteralPath $targetZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne '7330b9c47e4c5ca894ee0422fbd5a206067fc8611e9bf79b8ee8d28803761072') {
        throw "Das ZIP entspricht nicht dem freigegebenen AgentHub-6.0-Paket: $hash"
    }
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
    Write-Host 'Installer: irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex'
}
finally {
    if (Test-Path -LiteralPath $repoRoot) { Remove-Item -LiteralPath $repoRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
