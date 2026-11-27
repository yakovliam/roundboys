# Factory preset import: November 26, 2026

The new build imports the 14 checked Little Radiator factory presets.
Right-click the faceplate and select **Import .toy…**.
The importer restores Bypass, Heat, Mix, Bias, and Noise.

This first version identifies exact archive data with SHA-256.
It uses parameter values measured through the original AU's public state interface.
It does not yet decode arbitrary archives.
It does not load the original AU during import.

## Observed original import path

The original AU returns a dictionary through `kAudioUnitProperty_ClassInfo`.
That dictionary includes `data` and `soundtoys-data`.

`data` contains the five host parameters in this observed build.
Its first 12 bytes contain two zero words and a parameter count of five.
Each following entry contains a big-endian parameter ID and a big-endian float32 value.
The field contains 52 bytes for these observations.

`soundtoys-data` contains text that starts with `WIDGET`, `VERSION`, and `SAVED_BY_VERSION`.
The current original writes additional `BUILDNUM` and `PRESET` fields when it saves host state.
The older bundled files contain an `ARCHIVE` field.

The probe copies the original ClassInfo dictionary.
It replaces `soundtoys-data` with the preset's text before the first NUL byte.
The reference probe excludes the binary trailer from that text.
It removes `data` to prevent that field from restoring the previous parameters.
The probe sends the dictionary through `AudioUnitSetProperty`.
The original loads all 14 bundled archives through this path with status zero.

The probe checks each file in two separate processes.
All five parameter values match between both loads.
It uses the licensed original without a debugger or binary changes.
This check does not establish support for every original preset version.

## Checked controls

All checked presets set Bypass to zero and Noise to one.
The table rounds values for display.
The Rust table preserves the observed float32 bits.

| Preset | Heat | Mix | Bias |
|---|---:|---:|---:|
| Acoustic Tamer | 0.410 | 1.000 | 0 |
| Bass Beef | 0.740 | 0.500 | 1 |
| Bass Bite | 0.600 | 0.870 | 1 |
| Bit of Grit | 0.760 | 0.500 | 1 |
| Default | 0.500 | 1.000 | 0 |
| Getting Warmer | 0.645 | 0.660 | 0 |
| Guitar Double Edge | 1.000 | 0.130 | 1 |
| Hot Tip | 0.920 | 0.070 | 0 |
| Luke Warm | 0.570 | 0.580 | 0 |
| Rhodes Toaster | 0.535 | 1.000 | 0 |
| TakeTheChillOff | 0.315 | 1.000 | 1 |
| Tasteful | 0.655 | 0.500 | 0 |
| Touch of Tube | 0.510 | 0.090 | 1 |
| Vocal OverHeated | 1.000 | 0.380 | 0 |

## Rust import behavior

The importer reads at most 1 MiB.
It checks the plug-in name and preset format version.
It accepts carriage-return, line-feed, and CRLF line endings.
It preserves binary data after the text fields.

The importer hashes the ARCHIVE field and finds an exact checked match.
A renamed file works when its archive remains unchanged.
Header line endings and the writer version do not change that match.
An unknown or changed archive returns an error.
A matching filename alone cannot select parameter values.

The editor decodes all five values before it changes a parameter.
It checks the values and saves the previous settings.
If a setter fails, it attempts to restore all previous settings and reports the error.
The state format saves the imported parameter values for later recall.
It does not yet save the imported preset name.

## Tests

The import comparison checks all 14 files against the saved original observations.
Every imported float32 value matches the original exactly.

Nine Rust tests pass.
They include SHA-256 vectors, changed archives, wrong plug-in names, line endings, oversized files, and unchanged outputs on failure.
The native host checks import, parameter readback, saved-state recall, and editor creation.
Its audio checks still match the direct Rust model.
This verifies control import, not sound matching with the original DSP.

The import command now uses the faceplate context menu.
The native host exercises its decoder and parameter APIs directly.
An end-to-end file-panel test in REAPER remains open.
The existing REAPER instance still uses the earlier installed build.
The new build stays at `target/LittleRadiatorRust.component`.

## Local evidence

Evidence stays under `evaluation/reimplementation/little-radiator/` in the outer repository.

| Record | Directory |
|---|---|
| Original state layout | `presets/state-20261126T060600143240Z/` |
| First original preset load | `presets/load-20261126T060650738906Z/` |
| Both loads of all factory presets | `presets/factory-20261126T060848831395Z/` |
| Rust import comparisons | `presets/import-check-20261126T061206985798Z/` |
| Rust checks | `rust-checks/20261126T061145179418Z/` |
| Native checks and editor image | `host-tests/20261126T061216736507Z/` |

REA opens the saved analysis binary for static inspection.
Its Ghidra import exceeds the 330-second startup limit.
The failure record stays in `presets/rea-timeout.json`.
The static inspection also locates the 64-character table and its encoder loop with local disassembly.
That finding does not establish the complete archive grammar or compression scheme.
The public host observations provide the control mappings for this first importer.

## Remaining work

Recover the full ARCHIVE grammar and verify it with generated control combinations.
Support custom presets without an exact archive match.
Check modern saved presets with their optional headers.
Test the file panel and host automation in REAPER.
Measure the DSP separately before claiming that imported presets produce matching sound.
