# HP3 VU1 Trace v2 — implementation design

Status: design only; no PCSX2 source patch has been applied or compile-tested.

## Confirmed local source facts

- `HP3CaptureContext` is defined in `pcsx2/Vif_Dma.h` and contains `id`, `asset_ref_id`, `batch_id`, VIF/DMA metadata and payload hashes.
- `vu1ExecMicro(u32 addr, const HP3CaptureContext* hp3_capture)` passes the context to `VU_Thread::ExecuteVU` when MTVU is enabled.
- MTVU serializes the context into its ring buffer. The worker reads it immediately before calling `CpuVU1->Execute(vu1RunCycles)`.
- The interpreter fetches the current instruction in `_vu1Exec(VURegs* VU)`: the guest PC is the value of `VU->VI[REG_TPC].UL` before it is incremented by 8; lower word is `ptr[0]`, upper word is `ptr[1]`. `vu1Exec()` increments `VU->cycle` before entering `_vu1Exec()`.
- microVU dispatch occurs in `recMicroVU1::Execute(u32 cycles)`, immediately before calling `microVU1.startFunct`. This is a JIT block-level observation, not a per-guest-instruction hook.
- `VURegs` must not be extended for trace state.

## Proposed implementation

1. Add a dedicated trace helper (header-only or a separately registered translation unit) behind `HP3_VU1_TRACE`, default disabled.
2. Maintain capture metadata in a thread-local trace scope. Enter the scope around the actual VU1 execution:
   - non-MTVU: scope in `vu1ExecMicro` around `ExecuteBlock(1)` / `Execute(vu1RunCycles)`;
   - MTVU: scope in the worker after reading `HP3CaptureContext` and around `CpuVU1->Execute(vu1RunCycles)`.
   Scope destruction must restore the previous context on every exit.
3. Interpreter hook in `_vu1Exec`: capture PC before TPC increment, `ptr[0]`, `ptr[1]`, and the already-incremented VU cycle. Record only when the trace switch is enabled.
4. microVU hook in `recMicroVU1::Execute`: record backend=`microVU`, start PC, requested cycle budget, capture ID, and elapsed wall-clock duration around `startFunct`. Do not label this as instruction-level tracing.
5. Write to a bounded per-thread buffer and flush in batches to a trace file separate from the existing DMEM captures. Avoid opening a file for each instruction. Include a maximum record count / size and an explicit overflow counter.
6. Keep trace output disabled by default. No hard-coded game asset IDs, PCs, or Harry-specific behavior.

## Safety / acceptance gates

- Do not touch existing HP3 capture serialization, metadata, or DMEM snapshot behavior.
- Do not change `VURegs` or the layout of existing emulator state.
- Do not run `git clean`, `git reset`, checkout, or overwrite local worktree changes.
- Apply only to a clean copy or through a reviewed patch against the user's current worktree.
- First build with trace disabled, then with trace enabled.
- Test both MTVU on/off and both VU1 interpreter/microVU backends.
- Verify that no trace file is produced when disabled, and that trace records carry the expected capture ID when enabled.
- Verify bounded-buffer overflow behavior and compare emulator behavior/performance with tracing disabled vs enabled.

## Current status

The read-only preflight passed against the user's local tree. The local PCSX2 worktree has seven modified tracked files and numerous untracked backups. This design does not authorize overwriting or reverting any of them. The implementation remains pending until a patch can be reviewed and compiled against that exact local tree.
