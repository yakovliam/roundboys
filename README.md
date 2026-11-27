# RoundBoys

RoundBoys contains AU plug-ins for team testing on Mac.
Decapitator and Little Radiator have working test builds.
The other 21 plug-ins remain source templates.
The audio models remain provisional. They do not yet match the original audio.

## Build a test release

Use an Apple silicon Mac with macOS 11 or later.
Install Rust and the Xcode command line tools.
Restore the local interface assets and preset fixtures first.
Run this command from the repository root:

```sh
python3 tools/release.py --version 0.1.0
```

The command checks both plug-ins and builds a PKG installer and a ZIP archive.
It also writes checksums and a release manifest.
The output stays in `dist/roundboys-0.1.0-macos-arm64/`.
The command stops if that directory already exists.
It does not install or upload files.

The installer targets the current user's `Library/Audio/Plug-Ins/Components` directory.
It updates only `Decapitator.component` and `LittleRadiator.component`.
The AU identifiers remain unchanged so existing test projects can load them.
Intel Mac builds and other plug-in formats remain unavailable.

Every push to `main` queues a GitHub Actions build with downloadable artifacts.
Start the local Mac runner to build with local assets.
Manual runs can create a draft prerelease.
See [the release guide](RELEASING.md) for signing and team delivery.

## Source and local files

Git stores source files only. The repository uses no Git LFS.
Build output, licensed images, preset fixtures, logs, and credentials stay outside Git.
The local asset directory contains only the images required by the new editor.
The build does not include original executables or PACE.
The analysis repository and its evidence remain in their original directory.

The local move preserves the source templates for all 23 plug-ins under `plugins/`.
The old analysis tools still use paths in the analysis repository.
Use the root release command for the independent RoundBoys build.
