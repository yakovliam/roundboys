# Decapitator interface evidence

## Scope

This note records local image and preset evidence. The original program does not run during this check.
The source bundle is `reference/Decapitator.component`.
All image names below refer to `Contents/Resources/` in that bundle.

## Faceplate

`DecapitatorBackground_2x.png` measures 1600 × 700 pixels.
Its name supports an 800 × 350 layout at the normal scale.
The image shows dark metal, four screws, a Decapitator title, and a lower grille.
The lower grille starts near y = 292 at the normal scale.
The Soundtoys logo occupies its left side. The STYLE label occupies its right side.
Five short white marks extend across the grille.
Two upper white rules flank an empty area on the left.
The image contains no knob labels, knob scales, buttons, or meter.
Thus, those parts need separate drawing or separate images.

The panel itself contains no development header.
`Preset_Background.png` measures 1300 × 35 pixels.
`Preset_DisplayBackground_72.png` measures 252 × 25 pixels.
These files belong to a separate preset bar. They do not set the panel height.

## Control images

| Image | Full size | Observation or inference |
|---|---|---|
| `WM_KNOB_PULTEC_95.png` | 99 × 12350 | A vertical knob strip. 130 frames of 95 pixels fit its height. |
| `WM_KNOB_PULTEC_64.png` | 67 × 8320 | A vertical knob strip. 130 frames of 64 pixels fit its height. |
| `WM_LIGHTEDPUSHBUTTON_50.png` | 50 × 100 | Two square states. The second state has an orange light. |
| `WM_ANIMATED_SWITCH_HALFSIZE_VERT.png` | 24 × 270 | Ten visible lever positions. A 27-pixel frame height fits the strip. |
| `WM_DECAPITATOR_METER.jpg` | 210 × 16766 | A vertical needle strip. 101 frames of 166 pixels fit its height. |

Frame counts for knobs and the meter are arithmetic inferences.
They need a crop check before use in a renderer.
The image widths include space around the visible parts.
Do not assume that a knob image has a square frame.

The meter image shows a white dial in a black case.
The needle moves from left to right down the strip.
The dial has an ATTITUDE label. The image alone does not give the meter response law.

## Named controls and layout

The image directly confirms the STYLE label and five style positions.
It does not show the individual style names.
A likely control set includes Drive, Punish, Low Cut, Thump, Tone, High Cut, Steep, Output, Auto, and Mix.
The likely style names are A, E, N, T, and P.
These names remain unconfirmed by this image and preset check.

A proposed layout uses a large Drive knob on the left and a meter above the center.
Smaller filter and tone knobs occupy the middle.
Output and Mix occupy the right side.
Five style buttons occupy the lower grille.
This layout is an implementation proposal. The local background does not prove control centers.

## Preset evidence

The local directory contains 47 `.toy` files.
All files name the widget `Decapitator` and the archive version `4`.
The 46 category presets name saved version `5.3.2` and build `15253`.
`Default.toy` names saved version `5.0.1` and has no `BUILDNUM` field.
The archive text does not expose control values as plain parameter fields.
This check does not decode the archive.

| Directory | Count |
|---|---:|
| Root (`Default.toy`) | 1 |
| `01 Bass` | 5 |
| `02 Drums` | 13 |
| `03 Effects` | 9 |
| `04 Guitar` | 7 |
| `05 Reamping` | 3 |
| `06 Vocals` | 9 |
| Total | 47 |

## RoundBoys treatment

Reuse `../little-radiator/assets/roundboys-faceplate-generated.png` for the RoundBoys wordmark.
That image measures 2170 × 725 pixels.
The white RoundBoys wordmark occupies the right side of that green panel.
Extract only the wordmark area for the Decapitator logo position.
Preserve the existing wordmark shape. Do not create a new logo.
Keep the Decapitator title and dark panel treatment.
Omit the development header, as requested.

## Unknowns

The original control coordinates, ranges, defaults, and unit labels remain unconfirmed here.
The knob angle limits and frame selection rules remain unconfirmed.
The meter calibration and smoothing remain unconfirmed.
The preset archive needs a separate format study before preset values can be imported.

## Source editor

`native/editor.mm` defines `DCDevView` and `DCDevViewFactory`.
The view measures 800 × 350 points and has no header.
It reads and writes the twelve parameter IDs supplied for the new Audio Unit.
Six knobs show normalized values. Double-click restores the supplied default.
Drag up to increase a knob value. Hold Shift for a small change.
The editor sends host events when a parameter gesture starts or ends.
A timer reads host parameter changes at 20 Hz.

The control positions remain inferred. The original editor does not run during this work.
The knob drawing uses frames 15 through 115 from each 130-frame strip.
This frame span is a prototype choice. The original angle span remains unknown.
The meter now uses the live signal. Its original calibration remains unknown.
The style buttons use the two light states in the pushbutton image.
The other switches use the first and last lever frames.

The editor crops the existing RoundBoys source at x = 1360, y = 320, width = 650, height = 135.
Those coordinates use the source bitmap pixel grid.
It uses neutral bright pixels to create a white wordmark with transparency.
The green panel pixels receive zero alpha.
A repeated grille patch from the original faceplate covers the old Soundtoys logo.
The build must copy the existing source image as `RoundBoysFaceplate.png`.
The editor now includes a preset bar with import and save actions.

A Clang syntax check passes with ARC and C++17.
No Audio Unit installation or launch forms part of this check.

## Original editor capture

The licensed original now supplies an editor image through its public Cocoa interface.
REA records the capture as `ev_d4f7e83417a91a3c5179b4219019ee188b8902fa8040193293fe6b02b16d2f24`.
The image stays in `evaluation/reimplementation/decapitator/original-editor.png` under the outer repository.
The original returns a view of 1305 by 634.5 points, including its toolbar and frame.
The new editor uses the 800 by 350 faceplate area.
A 36-point preset bar brings the full view to 800 by 386 points.

The control positions now follow this capture, scaled to the faceplate.
Drive uses the large knob at approximately (53,140).
The filter and Tone knobs use (243,210), (368,210), and (493,210).
Output uses (584,120). Mix uses (679,210).
The meter uses (300,10) with a 210 by 166 size.
The Punish button uses (140,47) with a 50 by 50 size.
The five Style buttons start near x=230 at y=299.

The original confirms the A, E, N, T, and P style labels.
It confirms the visible Low Cut range of 20 Hz to 1 kHz.
It confirms the visible High Cut range of 1 kHz to 20 kHz.
It confirms the visible Output range of -24 dB to 0 dB.
These labels do not establish the internal parameter mapping laws.
The new layout follows the capture, but exact font rendering and pixel matching remain open.
The meter now moves with audio. Its response remains provisional.
The RoundBoys wordmark uses the same generated lettering as Little Radiator.
Right-click the panel to import a checked factory preset.

## Preset and meter update, November 26, 2026

The preset bar supplies grouped factory presets, user presets, previous/next buttons, import, save, and bypass.
The menu and the standard AU preset interface share the current preset state.
The name shows an asterisk after a control change.

The audio thread publishes a meter value through an atomic property.
The editor reads that value at 20 Hz.
The needle returns to rest when rendering stops.
The meter measures the final output after Mix, Bypass, and output trim.
The reference level is -6 dBFS at 0 VU.
This level and the response times remain prototype choices.

The native AU test checks needle movement with a tone and return to rest with silence.
It also checks user preset save and load, factory selection, and rejection of a preset for another plug-in.
The current images are in `evaluation/reimplementation/decapitator/validation-20261127T004027786010Z/`.
