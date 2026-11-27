# Little Radiator

This repository contains the first independent Rust audio model and a macOS Audio Unit bridge.
The wet model remains provisional. It does not yet reproduce the original sound.

The AU uses separate development identifiers: `aufx / LrD1 / StDv`.
Its name is `ST Analysis: Little Radiator`.
The build stays in `target/LittleRadiator.component`.
The build script does not install the AU.

The [implementation report](IMPLEMENTATION-REPORT.md) records the research, tests, and remaining work.

## Build

Run these commands from the repository root:

```sh
cargo test --offline -- --include-ignored
python3 tools/build_au.py
```

The build needs Rust, the macOS SDK, and the local reference images.
The local preset test needs all 14 original preset files.

The audio core uses Rust without external crates.
A small Objective-C++ bridge provides the AU interface and the Cocoa editor.
The build uses the current Mac architecture.
It does not yet build a universal binary.

## Check

```sh
python3 tools/check_rust.py
python3 tools/test_au.py
python3 tools/analyze_reference.py
python3 tools/compare_reference.py
```

The native host needs access to macOS audio services and the window server.
The last two commands read saved reference audio. They do not run the original plug-in.
The comparison command reports errors. A successful command does not mean that the sounds match.

All evidence stays under `evaluation/reimplementation/little-radiator/` in the outer repository.
Each run uses a new directory.
The evidence remains after `cargo clean`.
Git ignores this evidence directory.

## Implemented behavior

- Five parameters use the observed IDs, names, ranges, and defaults.
- The Rust model processes stereo audio with fixed storage during processing.
- The AU supports stereo float32 audio from 8 kHz to 192 kHz.
- Parameter state can save and restore in our own versioned format.
- The preset reader preserves the original bytes, including binary trailing data.
- The editor uses local original panel images with the user's permission.

The importer supports the 14 checked factory `.toy` archives.
Custom archives remain unsupported. See [PRESETS.md](PRESETS.md).
The wet model uses provisional gain, saturation, filters, smoothing, and noise.
The editor provides Import .toy in its right-click menu.
The original preset browser, host gestures, and full automation remain open.
the audio host testing and `auval` testing also remain open.

## Local reference

`reference/LittleRadiator.component` contains the original AU.
`reference/presets/` contains its 14 preset files.
Git ignores these files.
The build copies three image assets into the local build only.
It does not link original executable code or load the original AU.

The original identifiers remain `aufx / LRD  / SToy`.
The subtype includes a trailing space.
See [BEHAVIOR.md](BEHAVIOR.md) for the recorded original host behavior.

## Import a checked factory preset

Right-click the faceplate in the editor of the new build.
Select **Import .toy…**.
Select a file from `reference/presets/`.
Custom or changed archives return an error.
The existing installed the audio host copy needs an update before this button appears there.

The command-line importer also prints the restored values:

```sh
cargo run --offline --release --bin import-preset -- "reference/presets/Bass Beef.toy"
python3 tools/check_factory_import.py
```

## RoundBoys faceplate

The custom editor now measures 500 by 145 points.
The full development header is removed.
The generated RoundBoys wordmark replaces the manufacturer logo region.
The other original faceplate pixels remain unchanged.
The image generation record and prompt stay in `assets/roundboys-generation.md`.
The local build needs `assets/roundboys-faceplate-generated.png`.

## RoundBoys repository

Use the root release guide for the current build and distribution process.
The older evidence paths refer to the separate analysis repository.
Local image assets and preset fixtures stay outside Git.
