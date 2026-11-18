# HP3RC2

Tools and diagnostics for the HP3 / PS2RC workstream.

## HP3 VU1 Dispatch Trace

- Experimental first attempt: tools/vu1-dispatch-trace/Apply-HP3-VU1-DispatchTrace.ps1
- Safe v2 preparation: branch feature/hp3-vu1-trace-v2
- Design gate: docs/HP3-VU1-TRACE-V2.md
- Read-only preflight: tools/vu1-dispatch-trace/Test-HP3-VU1TracePrerequisites.ps1

The experimental first attempt is not approved for use. The v2 branch does not yet modify PCSX2 source. It adds a read-only source/worktree preflight and records requirements that must be met before a compile-tested patch is published.

### Run the preflight (Windows PowerShell 5.1)

~~~powershell
$script = Join-Path $env:TEMP 'Test-HP3-VU1TracePrerequisites.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/sonox99/HP3RC2/feature/hp3-vu1-trace-v2/tools/vu1-dispatch-trace/Test-HP3-VU1TracePrerequisites.ps1' -OutFile $script; Get-FileHash -Algorithm SHA256 $script; & $script -ProjectRoot 'F:\PS2RC-HP3'
~~~

The preflight only reads source files and Git status. It does not create backups, edit files, build PCSX2, or launch the emulator.

No successful build or runtime validation is claimed.
