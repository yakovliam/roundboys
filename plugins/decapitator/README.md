# RoundBoys Decapitator

This repository now builds an independent Rust AU prototype.
The editor uses the same RoundBoys lettering as Little Radiator.
It has no development header.

The audio model remains provisional.
It does not yet reproduce the original sound.
The meter now follows the final output signal.
Its calibration remains provisional.

The development identifiers are `aufx / Dcp1 / StDv`.
The AU name is `RoundBoys: Decapitator Rust`.
The original uses `aufx / DEC  / SToy`, including the subtype's trailing space.

## Build and check

Run these commands from this repository:

```sh
python3 tools/build_au.py
cargo test --offline -- --include-ignored
python3 tools/validate.py
```

The build needs Rust, the macOS SDK, the local reference images, and the shared RoundBoys PNG in the Little Radiator repository.
The build uses the current Mac architecture.
The AU stays at `target/DecapitatorRust.component`.
The build script does not install it.

Native checks need access to macOS audio services and the window server.
The validation script compares against saved reference audio and preset observations.
It does not run the original AU.

## Controls and presets

The AU implements all 12 observed host controls.
It provides five independent provisional style curves, Punish, filters, Tone, Mix, automatic gain compensation, and output trim.
Those algorithms and mapping laws remain design choices pending measurement.

Use the preset dropdown above the faceplate.
It lists 47 factory presets in groups.
Use the arrow buttons to select the previous or next factory preset.
Use **Save…** to save a user preset as `.aupreset`.
Use **Import…** to load a supported `.toy` or `.aupreset` file.
The preset name shows an asterisk after a control change.
The AU also supplies its factory presets through the standard host interface.

User presets use `~/Library/Application Support/RoundBoys/Decapitator/Presets`.
Each saved preset stores all 12 controls and its name.

The `.toy` importer has these limits:
The importer supports all 47 checked factory archives.
It restores all 12 observed control values exactly.
Custom archives remain unsupported.
The importer identifies exact archive hashes; it does not decode arbitrary preset data.

```sh
cargo run --offline --release --bin import-preset -- "reference/presets/01 Bass/Beefy.toy"
```

## Research and evidence

[BEHAVIOR.md](BEHAVIOR.md) records original host observations and implementation limits.
[INTERFACE.md](INTERFACE.md) records image resources and the editor capture.

The original component and presets stay in the ignored `reference/` directory.
New evidence stays under `evaluation/reimplementation/decapitator/` in the outer repository.
Evidence remains after `cargo clean`.
The reference capture tools require the licensed original.
They use its public AU interface without a debugger or binary changes.

The new AU does not link or load original executable code or PACE.
Its local build includes original image assets and the generated RoundBoys image.
