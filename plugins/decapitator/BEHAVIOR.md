# Decapitator behavior and implementation: November 26, 2026

The first Rust AU prototype now builds and passes the local host checks.
Its sound model remains provisional.
The current comparison reports zero exact full audio cases out of 25.

## Original host observations

The original is build 5.5.5.19885, with factory `DecapitatorAUFactory`.
REA confirms the original `aufx / DEC  / SToy` identity.
The subtype includes a trailing space.

The licensed original initializes successfully in the probe.
Its public parameter list contains 12 entries after initialization.

| ID | Name | Range | Default |
|---|---|---|---|
| 7 | Bypass | 0–1 | 0 |
| 10 | Style | 0–4 | 0 |
| 11 | Drive | 0–1 | 0 |
| 12 | Punish | 0–1 | 0 |
| 13 | LowCut | 0–1 | 0 |
| 14 | Tone | 0–1 | 0.5 |
| 15 | HighCut | 0–1 | 1 |
| 16 | Mix | 0–1 | 1 |
| 17 | AutoGain | 0–1 | 1 |
| 18 | LowThump | 0–1 | 0 |
| 19 | HighSlope | 0–1 | 0 |
| 20 | OutputTrim | 0–1 | 1 |

All entries report flags `0xc8a00010`.
The original reports unit code 1 for its Style entry, despite the five-value range.
The Rust AU uses the indexed unit for Style.
The original editor confirms the A, E, N, T, and P style labels.

The original's default host state contains a 108-byte `data` field.
It has a 12-byte header and 12 big-endian ID/float32 pairs.
The dictionary also includes `soundtoys-data`, which contains the text preset wrapper.

The default probe reports latency of 0.0014058956916099773 seconds at its default rate.
This corresponds to 62 frames at 44.1 kHz.
A separate saved-audio search finds 62 frames in the settled dry and bypass tones at 48 kHz.
The search tests integer delays from zero through 255 frames.
The settled tone error is approximately 1.7e-9 RMS.
Other rates and parameter transitions still need separate latency checks.

## Audio baseline

The capture saves two original renders for each of 25 cases.
Every original pair matches exactly.
The cases cover three rates, silence, an impulse, a tone, five styles, and changes to the remaining controls.
All runs use 256-frame buffers and one second of stereo float32 audio.
The rates are 44.1, 48, and 96 kHz.
Each result records commands, hashes, output sizes, exit status, and terminal output.

The default original silence contains nonzero output.
Its missing noise model contributes to the Rust comparison error.
The original's control transitions also affect the full-file comparisons.
Dry or bypass settings do not settle immediately.

## Factory presets

The directory contains 47 presets.
The 46 category presets use version 5.3.2 and BUILDNUM 15253.
Default.toy uses version 5.0.1 without BUILDNUM.
All use archive version 4 and widget name Decapitator.

The probe loads each file through the original's public ClassInfo property in two fresh processes.
It replaces soundtoys-data with the preset text and removes the fallback data field.
It passes only text before the first NUL byte to the original.
All 94 loads succeed.
Each repeated pair restores the same 12 values.

The Rust importer checks the widget, version, optional build number, and archive identity.
It uses SHA-256 to select the measured factory control values.
All 47 imported sets match the observed float32 values exactly.
The importer preserves the original file bytes and trailing data.
Unknown archives return an error without changing output values.
This is factory import support, not a general archive decoder.

## Rust model and editor

The processor uses independent saturation curves for the five styles.
Its filters, smoothing, gain compensation, interpolation, and trim laws remain provisional.
The visible filter endpoint labels guide its provisional frequency ranges.
Those labels do not establish the original mapping laws or circuit responses.
The model uses a fixed 62-frame delay.
The correct original delay at other rates remains open.

The renderer uses fixed audio storage and performs no allocation during processing.
The AU supports stereo float32 data from 8 kHz through 192 kHz.
The new state format saves and restores its own parameter values.
It does not claim original AU state compatibility.

The editor uses an 800 by 350 faceplate with the same RoundBoys wordmark as Little Radiator.
It omits the development header.
Control positions follow a captured original editor image after normalization to the faceplate.
Exact fonts, frame mapping, full toolbar behavior, and pixel matching remain open.
The meter shows an idle sprite. Its calibration remains unknown.
Preset import is in the faceplate right-click menu.

## Validation

Six Rust tests pass, including the local preset test and SHA-256 vectors.
The formatter and Clippy checks pass.
The native host loads the AU, reads all parameters, imports a preset, and checks state recall.
The host also creates the editor and saves its image.
The local signature check passes.

The checked native tone output matches the direct Rust renderer exactly.
It also remains identical across 64-, 256-, and 1,024-frame buffers.
Those checks validate the new implementation path.
They do not establish sound matching with the original.

| Reference case | Current RMS error |
|---|---:|
| Default 48 kHz tone | 0.014978 |
| Style A, Drive 0.6 | 0.326878 |
| Style P, Drive 0.6 | 0.077441 |
| Punish | 0.035291 |
| Mix dry, including transition | 0.016145 |

No exact audio cases pass out of 25.
REAPER playback, full automation, long sessions, and original DSP identification remain open.

## Evidence

All paths below are under the local `evaluation/reimplementation/decapitator/` directory.

| Record | Path |
|---|---|
| REA host metadata | `rea-initial.json` |
| Original default state | `default.plist` |
| Original audio pairs | `reference-20261126T065416386351Z/` |
| Original factory preset pairs | `presets-20261126T065627823954Z/` |
| Original editor capture | `original-editor.png` |
| Full current validation | `validation-20261126T070503134198Z/` |

REA host capture ID: `ev_37eb7ec8db2f6185257036b81c9cb94fe82b1ef2f97c2e99ce94baf8a3678274`.
REA original editor capture ID: `ev_d4f7e83417a91a3c5179b4219019ee188b8902fa8040193293fe6b02b16d2f24`.
Process sampling is partial. Network activity and unselected filesystem effects remain unknown.
No debugger or binary patch is used in these original host observations.
The Rust AU has no PACE dependency.

The final label-spacing check stays in `editor-20261126T070659612292Z/`.
The separate test copy is installed at `~/Library/Audio/Plug-Ins/Components/DecapitatorRust.component`.
The current REAPER process stays open.
Restart the test host to load the new AU from its component list.

## Preset and meter update, November 26, 2026

The preset menu now exposes all 47 measured factory presets.
The standard AU preset properties expose the same list to the host.
User presets save as `.aupreset` files.
The checked `.toy` import uses exact archive hashes.
Arbitrary custom `.toy` decoding remains unsupported.

The live meter follows final output power with a 150 ms average.
Its calibration does not yet match a measured original meter.
The native host checks meter movement and return to rest.
It checks factory selection, user preset save and load, and state recall.

Validation passes in `evaluation/reimplementation/decapitator/validation-20261127T004027786010Z/`.
Seven Rust tests pass. All 47 factory imports restore the measured controls.
All 25 model audio outputs match the previous model outputs.
None matches the original output exactly.
The preset and meter changes do not alter the model audio.

The updated test component is installed. The previous component has a local backup.
The separate REAPER session records successful AU discovery and editor creation.
Manual playback verification remains open because the test window presents an audio setup prompt.
UI control calls also time out. A process sample shows a normal AppKit event loop.
The evidence does not establish a plug-in deadlock.
See `evaluation/reimplementation/decapitator/reaper-current.json` for the test session path.

## Meter sensitivity correction, November 26, 2026

The earlier meter measures the signal after Drive gain but before saturation.
Drive and Punish add up to 50 dB there.
The extra 18 dB meter offset makes normal driven audio exceed the display range.
The unequal attack and release times also bias the power reading toward peaks.

The corrected meter measures the final stereo output with a 150 ms power average.
It uses -6 dBFS RMS as 0 VU. The display maximum remains +3 VU.
Output trim, Mix, and Bypass now affect the reading.
This calibration remains a design choice. Original meter matching remains open.

The level test checks four sine levels at 44.1, 48, and 96 kHz.
It also checks normal driven audio and return to rest after silence.
The native AU test checks that normal driven audio does not pin the needle.
Seven Rust tests and the native AU checks pass.
All 25 audio outputs retain their previous hashes.
Evidence: `evaluation/reimplementation/decapitator/validation-20261127T004950600662Z/`.
