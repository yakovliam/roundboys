# Implementation report: November 26, 2026

The first Little Radiator AU builds and runs in the local test host.
The wet sound model remains provisional.
None of the 32 full reference cases matches exactly.
The editor uses original panel images, but full interface matching remains open.
The other 22 Rust crates remain scaffolds.

## Research review

The review covers REIMPLEMENTATION.md, WORKLOG-PATH-B.md, PATCHING-STATUS-2026-11-25.md, and the test requirements and progress records.
It also checks the latest saved matrix, the recovery summary, and the local assets and presets.
The earlier HANDOFF.md and STATELESS-PROGRESS file describe older stages.
The newer work log and test records supersede their pending test statements.

The saved matrix `20261125T070222Z` contains 32 accepted cases and 128 accepted renders.
One run needs a retry.
The saved stress record reports 900 accepted trials with 10 retries.
The recovery summary reports 2,380 checked audio outputs and no evidence errors in its scope.
These are recorded results from the earlier agent, not new runtime observations in this pass.

The development copy still has rare exits, crashes, or incorrect audio.
Retries make the recorded cases useful for comparison.
They do not prove that the original-derived binary is stateless on every input or system.
The work log's universal claims about impossible patches exceed its finite test coverage.
The original-derived editor also crashes.
A working audio baseline does not establish editor or preset compatibility.

This pass does not change or execute the original binary.
It does not change any earlier patched binary.
It uses saved audio to begin independent source work.

## New observations

The review checks both saved original renders for each of the 32 cases.
All 64 file hashes match their recorded hashes.
Each original pair matches exactly.

The settled dry and bypass tone cases show a 48-frame delay at 48 kHz.
A search over delays from zero through 255 frames finds this result.
Its error against the generated input tone is approximately 1.7e-9 RMS.
This measurement covers the settled tone cases only.
It does not establish latency at every rate or setting.

The dry and bypass cases begin with processed audio before they settle.
Their early peak reaches approximately 0.151 for an input peak of 0.1.
Their final peak settles to 0.1.
Thus, an immediate parameter change cannot represent the saved startup behavior.
The original smoothing law and transition length remain unknown.

The default silence case contains small deterministic output.
The channels differ when Noise is on.
The noise-off tone case has identical channels.
The generator, filters, and original seed rules remain unknown.

All 14 local preset headers now parse and preserve the original bytes.
The files use old Mac carriage-return line endings.
`Default.toy` contains 65,536 bytes, including binary data after its fourth text line.
The parser keeps this trailing data unchanged.
The ARCHIVE field and trailing data remain opaque.
No original preset can yet set the Rust controls.

REA checks the original Info.plist in a resource-only session.
Its evidence ID is `ev_b699069d72e1c99be7a59a416197d466328b653a4278e5d0da3cf535bb17186a`.
It confirms the original `aufx / LRD  / SToy` identity and version 5.5.5.19885.
This resource check does not recover DSP behavior.
The session evidence stays local.

## Source implementation

The Rust core implements five parameter IDs, names, ranges, and defaults from BEHAVIOR.md.
It rejects unknown IDs, invalid values, and nonfinite values.
It saves and restores its own versioned parameter state.
That format does not claim compatibility with original AU state.

The processor uses fixed stereo delay storage and performs no allocation during processing.
Its provisional wet path contains gain, saturation, filters, smoothing, and deterministic noise.
Its coefficients and generator are independent design choices.
They are not recovered Soundtoys algorithms.
The processor supports sample rates from 8 kHz through 192 kHz.

The Objective-C++ bridge provides the AU factory, stream setup, parameter access, rendering, state, and Cocoa editor.
The development AU uses separate identifiers: `aufx / LrD1 / StDv`.
It does not replace the original AU registration.
The build contains no original executable code or PACE library.

The user confirms permission to reproduce the interface.
The build copies three original PNG files from the local reference directory.
The panel, knob, and switch images remain local.
The editor supports Heat and Mix dragging, plus Bias and Noise switches.
The control placement and sprite mapping remain provisional.
The original toolbar, preset menu, display sizes, and complete interaction behavior remain open.
A development heading identifies the current model.

The implementation uses recorded behavior and independently written source.
This session does not establish a formal separation between analysis and implementation teams.

## Rust checks

Six tests pass, including the optional local preset test.
The tests check state round trips, invalid data, buffer boundaries, delay, extreme settings, and all 14 preset headers.
The formatter check passes.
Clippy passes with warnings treated as errors.
The local evidence retains the earlier preset parser failures and the final passing run.

## Native host checks

The new AU loads and initializes in the local host.
All five parameter metadata queries pass.
The host changes Heat, saves state, changes Heat again, and restores the saved value.
The host also checks that the AU rejects NaN.

The host creates the Cocoa editor and saves an image.
Audio remains identical across 64-, 256-, and 1,024-frame buffers for the checked 48 kHz default tone.
The AU output also matches the direct Rust renderer exactly for that case.
The local code signature check passes.

The desktop sandbox blocks the first component-registration check.
The same check succeeds with access to macOS audio services.
The final host run completes outside that sandbox.
This is a local host result, not a the audio host or auval result.

## Sound comparison

The comparison tool runs the Rust model against all 32 saved original cases.
It checks reference hashes before each comparison.
It records source hashes, commands, output hashes, and numerical errors.
It never runs the original AU.

| Case | RMS error | Error relative to reference energy |
|---|---:|---:|
| 48 kHz tone, 64 frames | 0.004078 | -28.62 dB |
| Heat full | 0.107281 | -12.03 dB |
| Mix dry | 0.001349 | -34.51 dB |
| Noise off | 0.004072 | -28.63 dB |

These errors are measurements, not acceptance tolerances.
The comparison reports zero exact cases out of 32.
The current model is suitable for testing the implementation path.
It is not a faithful replacement for the original sound.

## Evidence

New evidence stays in `evaluation/reimplementation/little-radiator/` under the outer repository.
Git ignores this directory.
It remains after `cargo clean`.
No changes go to GitHub in this pass.

| Record | Local directory or file |
|---|---|
| REA resource evidence | `rea-resources-20261126.json` |
| Saved audio review | `reference-review/20261126T054237291319Z/observations.json` |
| Rust checks | `rust-checks/20261126T054522748326Z/` |
| Native host checks and editor image | `host-tests/20261126T054546439511Z/` |
| All audio errors | `comparisons/20261126T054523126712Z/summary.json` |

The current build stays in `au-plugins/little-radiator/target/LittleRadiator.component`.
Its build manifest records source, binary, and image hashes.
The build needs the local reference images to recreate the editor.

## Next work

1. Measure the original gain curves with Noise off and settled controls.
2. Separate its filters, saturation, Bias behavior, and oversampling from those measurements.
3. Measure control transitions and noise behavior across rates and buffer sizes.
4. Replace the provisional wet model and reduce the recorded errors.
5. Decode preset values and test preset and host-state recall.
6. Compare the editor against original screenshots at each supported size.
7. Add the original toolbar, host gestures, and full automation.
8. Test the new AU in the audio host and with auval.
9. Apply the checked host and measurement tools to the next plug-in.

New reference measurements need repeatable authorized results before they can become comparison data.
The existing matrix provides a bounded starting point.

## the audio host follow-up: November 26, 2026

The separate the audio host 7.86 test profile now loads the Rust AU and displays its editor.
The packaging fix changes the linker output from a shared library to a Mach-O bundle.
macOS discovers the corrected AU after its registry refresh.
The user registration contains a separate copy at `~/Library/Audio/Plug-Ins/Components/LittleRadiator.component`.
The session uses a separate profile and a four-second test tone.
Playback remains stopped. the audio host has no selected audio device yet.
This check confirms discovery, instance creation, and editor display.
It does not establish the audio host audio playback or render acceptance.

## Preset import follow-up: November 26, 2026

The new build imports all 14 checked factory archives.
All five control values match repeated original observations exactly.
The implementation uses exact archive hashes and an observed control table.
It does not yet decode custom archives.
Read [PRESETS.md](PRESETS.md) for the public import path, limits, controls, and tests.
The current the audio host process still uses the earlier installed build.

## RoundBoys faceplate follow-up: November 26, 2026

The editor removes the complete 35-point development header.
Its new size is 500 by 145 points.
The built-in image tool creates the RoundBoys wordmark from the supplied faceplate reference.
The editor blends only the generated logo region into the original faceplate.
Preset import remains in the faceplate right-click menu.
The native host checks pass after this change.
Audio remains unchanged in those checks.
The final preview stays in `host-tests/20261126T064615320879Z/editor.png` under the local evidence directory.
