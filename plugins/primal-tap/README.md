# PrimalTap

This Rust crate is a starting point for an Audio Unit. The crate has no audio processing or host entry point.

The original installer lists these Audio Unit identifiers. Spaces inside the quotes are part of the identifiers.

| Type | Subtype | Manufacturer | Factory |
|---|---|---|---|
| `'aumf'` | `'PT  '` | `'SToy'` | `'PrimalTapAUFactory'` |

## Local reference files

The analysis files are in `reference/`. This directory includes `PrimalTap.component` and the matching `.toy` files in `reference/presets/`. Git ignores this directory.

The common rhythm and shape files are in `../shared-reference/presets/`. See the [clean-room workflow](../README.md#clean-room-workflow).
