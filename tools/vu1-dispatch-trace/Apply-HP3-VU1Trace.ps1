# HP3 VU1 dispatch trace integration
# Safe, anchor-checked patch for the four local PCSX2 source files.
# PowerShell 5.1 compatible. Creates timestamped backups and never invokes Git.

$ErrorActionPreference = 'Stop'
$repo = 'F:\PS2RC-HP3\source\pcsx2-instrumented'
$root = Join-Path $repo 'pcsx2'
$targets = @(
    (Join-Path $root 'VU1microInterp.cpp'),
    (Join-Path $root 'x86\microVU.cpp'),
    (Join-Path $root 'MTVU.cpp'),
    (Join-Path $root 'VU1micro.cpp')
)

foreach ($path in $targets) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Datei fehlt: $path" }
}
$traceHeader = Join-Path $root 'HP3VU1Trace.h'
if (-not (Test-Path -LiteralPath $traceHeader -PathType Leaf)) { throw "Trace-Header fehlt: $traceHeader" }

function Replace-Once {
    param([string]$Text, [string]$Pattern, [string]$Replacement, [string]$Label)
    $count = [regex]::Matches($Text, $Pattern).Count
    if ($count -ne 1) { throw "Anker '$Label' muss genau einmal vorkommen; gefunden: $count. Keine Quelldatei wurde geschrieben." }
    return [regex]::Replace($Text, $Pattern, $Replacement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

$nl = [Environment]::NewLine
$contents = @{}
foreach ($path in $targets) { $contents[$path] = [System.IO.File]::ReadAllText($path) }

$p = $targets[0]
$t = $contents[$p]
$t = Replace-Once $t '(?m)^#include "MTVU\.h"\r?$' ('#include "MTVU.h"' + $nl + '#include "HP3VU1Trace.h"') 'Interpreter include'
$t = Replace-Once $t '(?m)^([ \t]*)ptr = \(u32\*\)&VU->Micro\[VU->VI\[REG_TPC\]\.UL\];\r?$' ('$1ptr = (u32*)&VU->Micro[VU->VI[REG_TPC].UL];' + $nl + '$1HP3VU1Trace::RecordInterpreter(VU->VI[REG_TPC].UL, ptr[0], ptr[1], VU->cycle);') 'Interpreter instruction hook'
$contents[$p] = $t

$p = $targets[1]
$t = $contents[$p]
$t = Replace-Once $t '(?m)^#include "microVU\.h"\r?$' ('#include "microVU.h"' + $nl + '#include "HP3VU1Trace.h"' + $nl + '#if HP3_VU1_TRACE' + $nl + '#include <chrono>' + $nl + '#endif') 'microVU includes'
$t = Replace-Once $t '(?s)(void recMicroVU1::Execute\(u32 cycles\)\s*\{\s*if \(!THREAD_VU1\)\s*\{\s*if \(!\(VU0\.VI\[REG_VPU_STAT\]\.UL & 0x100\)\)\s*return;\s*\}\s*)VU1\.VI\[REG_TPC\]\.UL <<= 3;' ('$1#if HP3_VU1_TRACE' + $nl + '        const u32 hp3_trace_start_pc = VU1.VI[REG_TPC].UL;' + $nl + '        const auto hp3_trace_start = std::chrono::steady_clock::now();' + $nl + '#endif' + $nl + '        VU1.VI[REG_TPC].UL <<= 3;') 'microVU dispatch start'
$t = Replace-Once $t '(?m)^([ \t]*)VU1\.VI\[REG_TPC\]\.UL >>= 3;\r?$' ('$1VU1.VI[REG_TPC].UL >>= 3;' + $nl + '$1#if HP3_VU1_TRACE' + $nl + '$1const auto hp3_trace_end = std::chrono::steady_clock::now();' + $nl + '$1const u64 hp3_trace_elapsed_ns = static_cast<u64>(std::chrono::duration_cast<std::chrono::nanoseconds>(hp3_trace_end - hp3_trace_start).count());' + $nl + '$1HP3VU1Trace::RecordMicroVUDispatch(hp3_trace_start_pc, cycles, hp3_trace_elapsed_ns);' + $nl + '$1#endif') 'microVU dispatch end'
$contents[$p] = $t

$p = $targets[2]
$t = $contents[$p]
$t = Replace-Once $t '(?m)^#include "Common\.h"\r?$' ('#include "Common.h"' + $nl + '#include "HP3VU1Trace.h"') 'MTVU include'
$t = Replace-Once $t '(?m)^([ \t]*)Read\(&hp3Capture, sizeof\(hp3Capture\)\);\r?$' ('$1Read(&hp3Capture, sizeof(hp3Capture));' + $nl + '$1HP3VU1Trace::ScopedCaptureContext hp3TraceContext(hp3Capture.id, hp3Capture.asset_ref_id, hp3Capture.batch_id);') 'MTVU worker context'
$contents[$p] = $t

$p = $targets[3]
$t = $contents[$p]
$t = Replace-Once $t '(?m)^#include "MTVU\.h"\r?$' ('#include "MTVU.h"' + $nl + '#include "HP3VU1Trace.h"') 'VU1micro include'
$t = Replace-Once $t '(?s)(void vu1ExecMicro\(u32 addr, const HP3CaptureContext\* hp3_capture\)\s*\{)' ('$1' + $nl + ' HP3VU1Trace::ScopedCaptureContext hp3TraceContext(hp3_capture ? hp3_capture->id : 0, hp3_capture ? hp3_capture->asset_ref_id : 0, hp3_capture ? hp3_capture->batch_id : 0);') 'EE-thread capture context'
$contents[$p] = $t

# All anchors validated before the first write. Back up every target first.
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupMap = @()
foreach ($path in $targets) {
    $backup = "$path.bak.hp3vu1trace.$stamp"
    Copy-Item -LiteralPath $path -Destination $backup -ErrorAction Stop
    $backupMap += [pscustomobject]@{ Source = $path; Backup = $backup }
}

try {
    foreach ($path in $targets) {
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($path, $contents[$path], $encoding)
    }
}
catch {
    foreach ($entry in $backupMap) { Copy-Item -LiteralPath $entry.Backup -Destination $entry.Source -Force }
    throw "Schreiben fehlgeschlagen; alle vier Dateien wurden aus den neu angelegten Backups wiederhergestellt. $($_.Exception.Message)"
}

'=== PATCH ANGEWENDET ==='
$backupMap | Format-Table -AutoSize
'=== DIFF STAT ==='
git -C $repo diff --stat -- pcsx2/VU1microInterp.cpp pcsx2/x86/microVU.cpp pcsx2/MTVU.cpp pcsx2/VU1micro.cpp
'=== DIFF CHECK ==='
git -C $repo diff --check -- pcsx2/VU1microInterp.cpp pcsx2/x86/microVU.cpp pcsx2/MTVU.cpp pcsx2/VU1micro.cpp
'=== TRACE HOOKS ==='
Select-String -Path (Join-Path $root 'VU1microInterp.cpp'),(Join-Path $root 'x86\microVU.cpp'),(Join-Path $root 'MTVU.cpp'),(Join-Path $root 'VU1micro.cpp') -Pattern 'HP3VU1Trace|hp3_trace_'
