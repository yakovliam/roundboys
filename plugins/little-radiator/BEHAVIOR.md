# Little Radiator behavior specification

This draft records public Audio Unit observations from build 5.5.5.19885 on Apple silicon. It does not specify the audio processing algorithm.

## Host interface

The Audio Unit uses type aufx, subtype LRD followed by one space, and manufacturer SToy. The original requires AudioUnitInitialize before it returns the global parameter list. A query before initialization returns -10867. Initialization returns 0 in the authorized test environment.

| Parameter ID | Name | Minimum | Maximum | Default | Unit code | Flags |
|---|---|---|---|---|---|---|
| 7 | Bypass | 0 | 1 | 0 | 1 | 0xc8a00010 |
| 8 | Heat | 0 | 1 | 0.5 | 0 | 0xc8a00010 |
| 9 | Mix | 0 | 1 | 1 | 0 | 0xc8a00010 |
| 10 | Bias | 0 | 1 | 0 | 1 | 0xd8a00010 |
| 12 | Noise | 0 | 1 | 1 | 1 | 0xc8a00010 |

These fields come from kAudioUnitProperty_ParameterInfo. The meanings of the nonstandard flag combinations and the parameter display strings need further checks. Do not infer the DSP mapping from the normalized ranges alone.

## Verified audio case

The authorized original processes a one-second stereo 440 Hz sine at amplitude 0.1. The test uses 48 kHz, float32, 256-frame buffers, and default settings. Two separate process runs produce identical output. The peak is 0.15981029. The output contains no nonfinite samples.

Raw reference output is in ../../evaluation/renders/original-1.f32. Its SHA-256 is 28cc2c1c948226053f6ef43ab57a76e53f416d916730d3d265a7464b0afc6648. Samples are interleaved little-endian float32.

## Required investigation

Measure each parameter across its range. Check automation, bypass, noise behavior, channel layouts, sample rates, latency, state recall, and preset loading. Recover the .toy grammar and define tolerances across repeated renders. The current observation set is insufficient to specify faithful audio processing.

## Evidence

The parameter probe source is ../../evaluation/parameter_probe.c. The captured metadata is ../../evaluation/logs/original-parameters.txt. The audio harness is ../../evaluation/render_probe.c.
