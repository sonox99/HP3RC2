[CmdletBinding()]
param([string]$ProjectRoot = 'F:\PS2RC-HP3')
$ErrorActionPreference = 'Stop'
$SourceRoot = Join-Path $ProjectRoot 'source\pcsx2-instrumented\pcsx'
$Required = @('VU1microInterp.cpp','x86\microVU.cpp','x86\microVU.h','MTVU.cpp','MTVU.h','VUmicro.cpp','VUmicro.h','VU.h')
$Checks = New-Object System.Collections.Generic.List[object]
function Add-Check([string]$Name,[bool]$Passed,[string]$Detail) {
    $script:Checks.Add([pscustomobject]@{Check=$Name;Result=$(if($Passed){'PASS'}else{'FAIL'});Detail=$Detail})
}
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { throw "PCSX2 source root not found: $SourceRoot" }
$targets = @{}
foreach($relative in $Required) {
    $path = Join-Path $SourceRoot $relative
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    Add-Check "File: $relative" $exists $path
    if($exists){$targets[$relative]=[System.IO.File]::ReadAllText($path)}
}
function Test-Contains([string]$File,[string]$Pattern,[string]$Label) {
    $exists = $targets.ContainsKey($File) -and $targets[$File].Contains($Pattern)
    Add-Check $Label $exists "Expected source anchor in $File"
}
Test-Contains 'VU1microInterp.cpp' 'ptr = (u32*)&VU->Micro[VU->VI[REG_TPC].UL];' 'Interpreter instruction fetch anchor'
Test-Contains 'VU1microInterp.cpp' 'VU->cycle++;' 'Interpreter cycle anchor'
Test-Contains 'x86\microVU.cpp' '((mVUrecCall)microVU1.startFunct)(VU1.VI[REG_TPC].UL, cycles);' 'microVU JIT dispatch anchor'
Test-Contains 'MTVU.cpp' 'Read(&hp3Capture, sizeof(hp3Capture));' 'MTVU capture context read anchor'
Test-Contains 'MTVU.cpp' 'CpuVU1->Execute(vu1RunCycles);' 'MTVU execution anchor'
Test-Contains 'MTVU.cpp' 'std::filesystem::create_directories(captureDir, fsError);' 'Existing capture output anchor'
Test-Contains 'MTVU.h' 'hp3CaptureDMEM[0x4000]' 'Existing DMEM capture buffer'
Test-Contains 'VUmicro.h' 'struct HP3CaptureContext;' 'Existing HP3 capture forward declaration'
if($targets.ContainsKey('VU.h')) {
    $collision = $targets['VU.h'].Contains('hp3TraceEnabled') -or $targets['VU.h'].Contains('HP3_VU1_TRACE')
    Add-Check 'No pre-existing trace state collision' (-not $collision) 'VU.h does not already contain HP3 trace fields'
}
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if($git) {
    $repoRoot = Join-Path $ProjectRoot 'source\pcsx2-instrumented'
    if(Test-Path -LiteralPath (Join-Path $repoRoot '.git')) {
        $status = & git -C $repoRoot status --short
        $gitExit = $LASTEXITCODE
        Add-Check 'Git status readable' ($gitExit -eq 0) 'Read-only git status command'
        if($gitExit -eq 0) {
            $changed = @($status | Where-Object { $_ -match '^\s*[MADRCU?!]{1,2}\s+' })
            Add-Check 'Existing worktree changes reported' $true ("Changed/untracked entries: {0}; no files are modified." -f $changed.Count)
            $status | ForEach-Object { Write-Host ("  " + $_) }
        }
    } else { Add-Check 'Git repository metadata' $false "No .git directory found at $repoRoot" }
} else { Add-Check 'Git executable' $false 'git.exe was not found; source checks still ran' }
Write-Host ''
Write-Host 'HP3 VU1 Trace v2 - read-only preflight' -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"
Write-Host "Source:  $SourceRoot"
Write-Host ''
$Checks | Format-Table -AutoSize -Wrap
$failed = @($Checks | Where-Object {$_.Result -eq 'FAIL'})
Write-Host ''
if($failed.Count -eq 0) { Write-Host 'Preflight passed. No source files were changed.' -ForegroundColor Green; exit 0 }
Write-Host ("Preflight found {0} issue(s). No source files were changed." -f $failed.Count) -ForegroundColor Yellow
exit 2
