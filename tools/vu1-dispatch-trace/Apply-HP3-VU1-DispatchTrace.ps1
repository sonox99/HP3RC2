[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$ProjectRoot = 'F:\PS2RC-HP3'
)

$ErrorActionPreference = 'Stop'
$SourceRoot = Join-Path $ProjectRoot 'source\pcsx2-instrumented\pcsx2'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $ProjectRoot "reports\vu1-dispatch-hook-backup-$stamp"

function Read-Source([string]$Name) {
    $p = Join-Path $SourceRoot $Name
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "Quelldatei fehlt: $p"
    }
    return [pscustomobject]@{
        Path = $p
        Text = [System.IO.File]::ReadAllText($p)
    }
}

function Replace-ExactlyOnce([string]$Text, [string]$Old, [string]$New, [string]$Label) {
    $count = ([regex]::Matches($Text, [regex]::Escape($Old))).Count
    if ($count -ne 1) {
        throw "Patch-Abbruch: '$Label' wurde $count-mal gefunden (erwartet genau 1). Keine Quelldatei wurde geändert."
    }
    return $Text.Replace($Old, $New)
}

$files = @{}
foreach ($name in @('VU.h','MTVU.h','MTVU.cpp','VU1microInterp.cpp')) {
    $files[$name] = Read-Source $name
}

$nl = if ($files['VU.h'].Text.Contains("`r`n")) { "`r`n" } else { "`n" }

# VU.h: diagnostic state is appended to VURegs; no existing register offsets change.
$old = "u32 ialucount;${nl}${nl}`tVURegs()"
$new = @"
u32 ialucount;

	// HP3 read-only VU1 dispatch tracing (active only for tagged Harry captures).
	bool hp3TraceEnabled = false;
	u32 hp3TraceCaptureId = 0;
	u32 hp3TraceBatchId = 0;
	u32 hp3TraceRemaining = 0;

	VURegs()
"@ -replace "`r?`n", $nl
$files['VU.h'].Text = Replace-ExactlyOnce $files['VU.h'].Text $old $new 'VURegs diagnostic fields'

# MTVU.h: separate snapshot for the complete 16 KiB VU1 micro memory.
$old = "alignas(16) u8 hp3CaptureDMEM[0x4000]{};"
$new = @"
alignas(16) u8 hp3CaptureDMEM[0x4000]{};
	alignas(16) u8 hp3CaptureMicro[0x4000]{};
"@ -replace "`r?`n", $nl
$files['MTVU.h'].Text = Replace-ExactlyOnce $files['MTVU.h'].Text $old $new 'MTVU micro snapshot buffer'

# MTVU.cpp: snapshot Micro before execution and enable tracing only for Harry asset captures.
$old = @"
					if (hp3Capture.id != 0)
					{
						std::memcpy(hp3CaptureDMEM, VU1.Mem, sizeof(hp3CaptureDMEM));
		Console.WriteLn("HP3_CAPTURE_DMEM worker_snapshot id=%u asset_ref=%s batch=%u bytes=%u", hp3Capture.id,
			HP3AssetReferenceName(hp3Capture.asset_ref_id), hp3Capture.batch_id, static_cast<u32>(sizeof(hp3CaptureDMEM)));
					}
"@ -replace "`r?`n", $nl
$new = @"
					VU1.hp3TraceEnabled = false;
					VU1.hp3TraceCaptureId = 0;
					VU1.hp3TraceBatchId = 0;
					VU1.hp3TraceRemaining = 0;
					if (hp3Capture.id != 0)
					{
						std::memcpy(hp3CaptureDMEM, VU1.Mem, sizeof(hp3CaptureDMEM));
						std::memcpy(hp3CaptureMicro, VU1.Micro, sizeof(hp3CaptureMicro));
						Console.WriteLn("HP3_CAPTURE_DMEM worker_snapshot id=%u asset_ref=%s batch=%u bytes=%u", hp3Capture.id,
							HP3AssetReferenceName(hp3Capture.asset_ref_id), hp3Capture.batch_id, static_cast<u32>(sizeof(hp3CaptureDMEM)));
						Console.WriteLn("HP3_CAPTURE_MICRO worker_snapshot id=%u asset_ref=%s batch=%u bytes=%u",
							hp3Capture.id, HP3AssetReferenceName(hp3Capture.asset_ref_id), hp3Capture.batch_id,
							static_cast<u32>(sizeof(hp3CaptureMicro)));
						if (hp3Capture.asset_ref_id == static_cast<u32>(HP3AssetReference::Harry))
						{
							VU1.hp3TraceEnabled = true;
							VU1.hp3TraceCaptureId = hp3Capture.id;
							VU1.hp3TraceBatchId = hp3Capture.batch_id;
						}
					}
"@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU pre-execution snapshot'

$old = "					CpuVU1->Execute(vu1RunCycles);"
$new = @"
					CpuVU1->Execute(vu1RunCycles);
					VU1.hp3TraceEnabled = false;
					VU1.hp3TraceRemaining = 0;
"@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU trace disable after execution'

# Save the complete micro memory beside the existing DMEM dump.
$old = @"
		const std::filesystem::path dumpPath = captureDir / (stem.str() + ".bin");
		const std::filesystem::path metaPath = captureDir / (stem.str() + ".meta.txt");

		std::ofstream dump(dumpPath, std::ios::binary | std::ios::trunc);
"@ -replace "`r?`n", $nl
$new = @"
		const std::filesystem::path dumpPath = captureDir / (stem.str() + ".bin");
		const std::filesystem::path microPath = captureDir / (stem.str() + ".micro.bin");
		const std::filesystem::path metaPath = captureDir / (stem.str() + ".meta.txt");

		std::ofstream dump(dumpPath, std::ios::binary | std::ios::trunc);
"@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU micro dump path'

$old = @"
		std::ofstream meta(metaPath, std::ios::out | std::ios::trunc);
"@ -replace "`r?`n", $nl
$new = @"
		std::ofstream microDump(microPath, std::ios::binary | std::ios::trunc);
		if (microDump)
		{
			microDump.write(reinterpret_cast<const char*>(hp3CaptureMicro), sizeof(hp3CaptureMicro));
			microDump.close();
		}

		std::ofstream meta(metaPath, std::ios::out | std::ios::trunc);
"@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU micro dump write'

$old = @'
			meta << "dmem_bytes=" << sizeof(hp3CaptureDMEM) << '\n';
'@ -replace "`r?`n", $nl
$new = @'
			meta << "dmem_bytes=" << sizeof(hp3CaptureDMEM) << '\n';
			meta << "micro_bytes=" << sizeof(hp3CaptureMicro) << '\n';
'@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU micro metadata'

$old = "		if (fsError || !dump || !meta)"
$new = "		if (fsError || !dump || !microDump || !meta)"
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU output validation'

$old = @"
			Console.WriteLn("HP3_CAPTURE_DMEM saved id=%u asset_ref=%s batch=%u path=%s bytes=%u", hp3_capture->id,
				HP3AssetReferenceName(hp3_capture->asset_ref_id), hp3_capture->batch_id, dumpPath.string().c_str(), static_cast<u32>(sizeof(hp3CaptureDMEM)));
"@ -replace "`r?`n", $nl
$new = @"
			Console.WriteLn("HP3_CAPTURE_DMEM saved id=%u asset_ref=%s batch=%u path=%s bytes=%u", hp3_capture->id,
				HP3AssetReferenceName(hp3_capture->asset_ref_id), hp3_capture->batch_id, dumpPath.string().c_str(), static_cast<u32>(sizeof(hp3CaptureDMEM)));
			Console.WriteLn("HP3_CAPTURE_MICRO saved id=%u asset_ref=%s batch=%u path=%s bytes=%u", hp3_capture->id,
				HP3AssetReferenceName(hp3_capture->asset_ref_id), hp3_capture->batch_id, microPath.string().c_str(), static_cast<u32>(sizeof(hp3CaptureMicro)));
"@ -replace "`r?`n", $nl
$files['MTVU.cpp'].Text = Replace-ExactlyOnce $files['MTVU.cpp'].Text $old $new 'MTVU micro saved log'

# VU1microInterp.cpp: record key dispatch instructions and 128 instructions after each recognized target.
$old = @"
	ptr = (u32*)&VU->Micro[VU->VI[REG_TPC].UL];
	VU->VI[REG_TPC].UL += 8;
"@ -replace "`r?`n", $nl
$new = @"
	const u32 hp3TracePC = (VU->VI[REG_TPC].UL & VU1_PROGMASK) >> 3;
	ptr = (u32*)&VU->Micro[VU->VI[REG_TPC].UL];
	VU->VI[REG_TPC].UL += 8;
"@ -replace "`r?`n", $nl
$files['VU1microInterp.cpp'].Text = Replace-ExactlyOnce $files['VU1microInterp.cpp'].Text $old $new 'VU1 interpreter current PC capture'

$old = @"
	if (uregs.pipe == VUPIPE_FMAC || lregs.pipe == VUPIPE_FMAC)
		VU->fmacwritepos = (VU->fmacwritepos + 1) & 3;
}
"@ -replace "`r?`n", $nl
$new = @"
	if (uregs.pipe == VUPIPE_FMAC || lregs.pipe == VUPIPE_FMAC)
		VU->fmacwritepos = (VU->fmacwritepos + 1) & 3;

	// Read-only trace: the dispatch instruction plus 128 executed instructions at its target.
	if (VU->hp3TraceEnabled)
	{
		const u32 hp3PendingTarget = (VU->branch > 0) ? ((VU->branchpc & VU1_PROGMASK) >> 3) : 0;
		if ((hp3TracePC == 0x01F || hp3TracePC == 0x021) &&
			(hp3PendingTarget == 0x273 || hp3PendingTarget == 0x331 || hp3PendingTarget == 0x4AB))
		{
			VU->hp3TraceRemaining = 128;
		}

		const bool hp3KeyPC = (hp3TracePC == 0x018 || hp3TracePC == 0x01B ||
			hp3TracePC == 0x01F || hp3TracePC == 0x021);
		if (hp3KeyPC || VU->hp3TraceRemaining > 0)
		{
			Console.WriteLn(
				"HP3_VU1_TRACE id=%u batch=%u cycle=%llu pc=%03X tpc=%03X branch=%u branchpc=%03X delay=%u "
				"vi1=%04X vi2=%04X vi6=%04X vf8=%08X,%08X,%08X,%08X",
				VU->hp3TraceCaptureId, VU->hp3TraceBatchId,
				static_cast<unsigned long long>(VU->cycle), hp3TracePC,
				(VU->VI[REG_TPC].UL & VU1_PROGMASK) >> 3, VU->branch,
				(VU->branchpc & VU1_PROGMASK) >> 3, VU->takedelaybranch ? 1u : 0u,
				static_cast<unsigned>(VU->VI[1].US[0]),
				static_cast<unsigned>(VU->VI[2].US[0]),
				static_cast<unsigned>(VU->VI[6].US[0]),
				VU->VF[8].UL[0], VU->VF[8].UL[1], VU->VF[8].UL[2], VU->VF[8].UL[3]);
		}
		if (VU->hp3TraceRemaining > 0)
			VU->hp3TraceRemaining--;
	}
}
"@ -replace "`r?`n", $nl
$files['VU1microInterp.cpp'].Text = Replace-ExactlyOnce $files['VU1microInterp.cpp'].Text $old $new 'VU1 interpreter dispatch trace'

# Verify all source transformations before touching disk.
foreach ($name in $files.Keys) {
    if ($files[$name].Text -eq [System.IO.File]::ReadAllText($files[$name].Path)) {
        throw "Patch-Abbruch: $name wurde nicht verändert. Keine Quelldatei wurde geändert."
    }
}

if (-not $PSCmdlet.ShouldProcess($SourceRoot, 'HP3 VU1 read-only dispatch trace patch')) {
    Write-Host "WhatIf: Alle vier Quelldateien wurden geprüft; es wurde nichts geändert."
    return
}

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($name in $files.Keys) {
    $backupPath = Join-Path $backupRoot $name
    Copy-Item -LiteralPath $files[$name].Path -Destination $backupPath
}
foreach ($name in $files.Keys) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($files[$name].Path, $files[$name].Text, $encoding)
}

Write-Host ''
Write-Host 'HP3 VU1 Dispatch Trace Patch angewendet.' -ForegroundColor Green
Write-Host "Source:  $SourceRoot"
Write-Host "Backup:  $backupRoot"
Write-Host 'Geändert: VU.h, MTVU.h, MTVU.cpp, VU1microInterp.cpp'
Write-Host 'Erfasst: vollständige 16-KiB VU1-Micro-Memory + Dispatch-Registertrace.'
Write-Host 'Hinweis: Für den Trace muss VU1 im Interpreter-Modus laufen; MTVU kann aktiv bleiben.'
Write-Host 'Es wurde kein Build gestartet und kein Emulator ausgeführt.'