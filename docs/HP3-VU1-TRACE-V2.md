# HP3 VU1 Dispatch Trace v2 — implementation gate

## Status

This branch is a safe preparation stage. It does not apply source changes and does not claim a successful build.

The existing experimental patch at tools/vu1-dispatch-trace/Apply-HP3-VU1-DispatchTrace.ps1 is NOT approved for use until its assumptions have been reviewed and a compile-tested replacement exists.

## Confirmed target behavior

- Interpreter: _vu1Exec(VURegs*) reads the current PC from VU->VI[REG_TPC].UL, then advances TPC by 8 bytes. Capture PC and both opcode words before advancing TPC.
- Interpreter cycle: vu1Exec() increments VU->cycle before _vu1Exec(). A trace record inside _vu1Exec() therefore observes the incremented cycle.
- microVU: recMicroVU1::Execute(u32 cycles) calls the generated native block through microVU1.startFunct. This is a block-dispatch hook, not a guest-instruction hook.
- MTVU: HP3CaptureContext is read from the ring buffer on the VU worker thread before CpuVU1->Execute(vu1RunCycles).
- Existing DMEM capture: hp3CaptureDMEM is copied on the worker and written by the EE thread after WaitVU(). Preserve this ordering and file format.

## v2 design requirements

1. One compile-time opt-in switch, default OFF.
2. A bounded, buffered trace writer; never open/close a file per guest instruction.
3. Interpreter records: capture ID, batch ID, cycle, PC, lower opcode, upper opcode.
4. microVU records: capture ID, batch ID, start PC, cycle budget, elapsed time, backend marker. Do not label these as per-instruction records.
5. MTVU capture context scoped to one execution and cleared on every exit path. Prefer explicit context passed to the trace API or a worker-thread-local scope guard; do not store transient capture identity in global mutable state.
6. Trace output separate from DMEM and micro-memory snapshots.
7. Existing user modifications and untracked files must remain untouched.
8. Patch application verifies every anchor before writing, preserves original encoding/newlines, creates timestamped backups, and provides tested rollback.
9. Dry-run before apply; tracing must not be silently enabled in normal builds.

## Required validation before an apply release

- Inspect complete definitions of VURegs, HP3CaptureContext, HP3AssetReference, and the MTVU ring-buffer worker.
- Verify VURegs layout/serialization assumptions. Prefer not to add fields to VURegs.
- Compile interpreter and recompiler configurations with tracing OFF.
- Compile interpreter configuration with tracing ON.
- Exercise MTVU ON and OFF.
- Confirm writer is bounded and does not block the VU worker on every instruction.
- Compare DMEM dump and metadata before/after instrumentation.
- Verify rollback restores only patch-owned files and refuses to overwrite files modified after apply.

## iPhone / Termius workflow

All operator commands in release documentation must be single-line Windows PowerShell 5.1 commands. Provide an audit step before applying. No multiline paste is required.

## Current limitation

The reviewed source excerpts do not establish the full VURegs definition, enum declarations, trace lifecycle, or build configuration. Therefore this branch intentionally ships only a read-only preflight and this implementation gate, not a speculative source patch.
