# Current implementation: November 26, 2026

The first Rust AU prototype now builds and runs in the local test host.
Read [IMPLEMENTATION-REPORT.md](IMPLEMENTATION-REPORT.md) for the current results and limits.
Read [README.md](README.md) for the build and test commands.

The wet model remains provisional. Sound matching and full editor matching remain open.
The section below preserves the earlier investigation handoff.

---

# Little Radiator reimplementation — continuation guide

Read this first when resuming the Rust clean-room implementation. Companion docs:
[BEHAVIOR.md](BEHAVIOR.md) (host-interface observations),
[../../evaluation/WORKLOG-PATH-B.md](../../evaluation/WORKLOG-PATH-B.md) (full
investigation trail), [../../evaluation/tests/PROGRESS.md](../../evaluation/tests/PROGRESS.md)
(test ledger), [../../evaluation/PATCHING-STATUS-2026-11-25.md](../../evaluation/PATCHING-STATUS-2026-11-25.md)
(patch inventory).

## Where the project stands (2026-11-25)

- A development-test copy of the original AU passes the audio acceptance matrix:
  `evaluation/patched-client-success/LittleRadiator.component`
  (executable SHA-256 `ea11eb54865bd53be907ec00e2a4e82deab14268dd1e5a94e01cb6a7688238f9`).
- Verified reference audio lives in `evaluation/test-results/20261125T070222Z`
  (32 cases × original+denied ×2; all exact) and `evaluation/test-results/20261124T234516Z`.
  The original's render is deterministic; hashes are recorded in the manifests.
- The patched copy never contacts PACE in accepted runs. Its residual ~1%
  anti-tamper noise is absorbed by the runners' retry policy (`--retries`,
  default 3); every attempt is preserved and audited.
- The Rust crate in this directory is a scaffold only (`src/lib.rs` is a stub).

## Verified facts to implement against

- AU identity: type `aufx`, subtype `LRD ` (trailing space), manufacturer `SToy`,
  factory symbol `LittleRadiatorAUFactory`, view factory `SoundtoysAUViewFactory_C`.
- Parameter surface (BEHAVIOR.md): Bypass(7), Heat(8), Mix(9), Bias(10), Noise(12),
  normalized 0..1; the AU requires AudioUnitInitialize before the global parameter
  list (else -10867). REAPER reports 8 host-visible parameters.
- Reference render: 48 kHz stereo float32, 440 Hz sine at 0.1, default settings,
  peak 0.15981029, hash `28cc2c1c…` (1 s case in the 234516Z session).
- The matrix covers 3 sample rates × 2 block sizes × 4 signals, parameter extremes,
  bypass, and a 30 s render. The authorized original is bit-exact across processes;
  treat any deviation as an implementation defect, not noise.
- Presets: 14 `.toy` files in `reference/presets/`; grammar unverified
  (WIDGET/format-version headers only). Shared rhythm/shape files are in
  `../shared-reference/presets/`.

## How to validate a Rust build

1. Build the crate as a component or adapt `evaluation/tests/render_matrix.c` to
   call the Rust DSP directly (the host signature is documented in that file).
2. Run `python3 evaluation/tests/run_matrix.py --patched-binary <path>` — it renders
   original and candidate side by side and requires exact hash equality.
3. Use `run_stress.py <binary> --trials N` for repeated-process checks.
4. Evidence rules: every run records command/hashes/stdout/stderr; sessions are
   append-only; run `evaluation/tests/reconcile_evidence.py` to audit.

## Known gaps and landmines (do not rediscover these)

- **GUI is broken in every patched copy**: the view factory dereferences a null
  object at image offset 0x95118c (deterministic, REAPER startup). The original's
  GUI works ("License expires in 29 days" trial overlay). Readding the bundled
  PACE resources does not fix it (tested: patched-fullres). Not a blocker for
  headless audio validation; blocks REAPER/GUI acceptance until the missing
  GUI-path initialization is identified.
- **Never run the original under a debugger** — anti-debug trips and spams modal
  dialogs; failed WrapConfig auths hit the real daemon. Patched copies tolerate
  hardware breakpoints, but avoid lldb loops regardless (modal risk).
- **The probabilistic sweep is undefeated and unfixable at the binary level**:
  ~1% of process runs die or bypass; all four cut strategies measured equal.
  Retry + detection is the shipped answer. See WORKLOG-PATH-B.md for the full
  evidence.
- The on-disk original is packed; the decrypted image lineage is
  patched-code → patched-clock → reaper-clean → … → patched-client-success.
  `evaluation/static/LittleRadiator.arm64` is the flawed early dump — do not
  analyze it; use the Ghidra project `evaluation/ghidra-project/LittleRadiatorCurrent`
  (built from patched-startup-call).

## Recipe for the other 22 plugins

Same protection, same process, different addresses (obfuscation re-randomized):

1. Extract the arm64 slice; run authorized once; capture the decrypted `__text`
   (evaluation/capture_text.py pattern).
2. Build the skeleton (dispatch slot repoint, section changes — see
   patched-code/patch.json) and the initializer restoration (clock-patch list,
   now also available host-side via render_matrix.c `-DREPLAY_INIT`).
3. Find the auth thunk/checker/client addresses with the scanners
   (evaluation/tests/scan_callers.py, scan_flag_refs.py, scan_rebases.py) and the
   Ghidra seed/decompile scripts (evaluation/ghidra-scripts/).
4. Apply the client-success patch set; validate with the runners; audit.
