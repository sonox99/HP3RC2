# HP3RC2

Tools and diagnostics for the HP3 / PS2RC workstream.

## HP3 VU1 Dispatch Trace (experimental)

Path: `tools/vu1-dispatch-trace/Apply-HP3-VU1-DispatchTrace.ps1`

This patcher is **experimental and unverified**. It has not been compiled against the target PCSX2 source tree. It uses exact-once source-text anchors and aborts if any expected anchor is missing or duplicated. Review the script and source diff before applying it.

### Download and inspect (Windows PowerShell 5.1)

```powershell
$script = Join-Path $env:TEMP 'Apply-HP3-VU1-DispatchTrace.ps1'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/vu1-dispatch-trace/Apply-HP3-VU1-DispatchTrace.ps1' -OutFile $script
Get-FileHash -Algorithm SHA256 $script
Get-Content $script
```

Run the dry-run first:

```powershell
& $script -ProjectRoot 'F:\PS2RC-HP3' -WhatIf
```

Only after reviewing the proposed changes and confirming the source tree is backed up, apply:

```powershell
& $script -ProjectRoot 'F:\PS2RC-HP3'
```

The patcher creates backups under `reports\vu1-dispatch-hook-backup-<timestamp>`. It does not build PCSX2 or start the emulator.

**Important:** The VU1 trace requires VU1 Interpreter mode. No successful build or runtime validation is claimed.
