# RoundBoys Little AlterBoy

Little AlterBoy is an independent AU with a Rust audio core and a native Mac editor.
The editor uses the RoundBoys lettering and the current preset bar.
The audio model remains provisional. It does not yet match the original audio.

## Controls

The AU supplies Pitch, Formant, Drive, Mix, Bypass, ShiftMode, and FormantLink.
Pitch and Formant cover -12 to +12 semitones.
The modes are Transpose, Quantize, and Robot.
Robot accepts MIDI notes. Its default target is C4.
Link follows the measured control behavior, including the saved unlinked Formant value.

The preset menu contains all 12 measured factory presets.
Import supports those exact `.toy` archives and the new `.aupreset` files.
Save writes user presets as `.aupreset` files.
User presets stay under `~/Library/Application Support/RoundBoys/LittleAlterBoy/Presets`.
Arbitrary custom `.toy` decoding remains unavailable.

## Build

Run `python3 tools/build_au.py` from this plug-in directory.
The component is `target/LittleAlterBoy.component`.
The name in the host is `RoundBoys: Little AlterBoy`.
The identifiers are `aumf / Lab1 / StDv`.
The bundle identifier is `dev.roundboys.LittleAlterBoy`.
The build uses local images in the ignored `assets/` directory.
No original executable or PACE library is linked or packaged.

The root release command includes this AU with the other active plug-ins.
The raw assets stay local for the Mac runner.

## Current limits

The independent model uses a phase vocoder with spectral envelope correction.
It supports stereo floating-point audio from 8 to 192 kHz.
It reports a fixed delay of 2048 samples.
The original delay differs and changes with the sample rate.
Pitch detection, mode transitions, formant quality, drive response, and transient behavior need further comparison.
The current MIDI path supports note on/off and all-notes-off messages.
Pitch bend, sustain, and other MIDI controls remain unverified.
Mono-only host layouts and complete host automation support remain open.
The interface follows the original capture. Exact pixel matching remains open.

Original observations stay in the separate analysis repository under `evaluation/reimplementation/little-alter-boy/`.
