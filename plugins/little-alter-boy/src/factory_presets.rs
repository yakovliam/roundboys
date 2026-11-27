//! Factory values measured through the licensed original public AU interface.
pub struct FactoryPreset {
    pub name: &'static str,
    pub archive_sha256: &'static str,
    pub values: [f32; 7],
}
pub const FACTORY_PRESETS: [FactoryPreset; 12] = [
    FactoryPreset {
        name: "01 Hard Tuner",
        archive_sha256: "fdbb9e55f533961824815fb647f4d7db5f77f5ad3c7d7858dd74abd1d575f32e",
        values: [0.0, 0.5, 0.5, 0.12, 1.0, 1.0, 1.0],
    },
    FactoryPreset {
        name: "02 Hard Tune Drive",
        archive_sha256: "1d05f9feab010a0d9cc217fffaf7dd07d2e2c9e8936b8d0814b9b0e2cf785f99",
        values: [0.0, 0.5, 0.55, 0.63, 1.0, 1.0, 0.0],
    },
    FactoryPreset {
        name: "03 Modern Double",
        archive_sha256: "11c0329989205bb5620c37ff835f5eb22b0ddf9c87fd7f112c8b9c1a36cbae25",
        values: [0.0, 0.5, 0.375, 0.39, 0.35, 1.0, 0.0],
    },
    FactoryPreset {
        name: "04 Older is Better",
        archive_sha256: "eec9cddd79dc83266ff56b2f5683a952f78297de636663eb9b7664ab47b76071",
        values: [0.0, 0.5, 0.39583334, 0.19, 1.0, 0.0, 0.0],
    },
    FactoryPreset {
        name: "05 Rich 5ths",
        archive_sha256: "6a21aa63caba06c157a4cbb6d8925e532ac46f209cd39c45f38f46e68c296b8a",
        values: [0.0, 0.29166666, 0.475, 0.31, 0.215, 0.0, 0.0],
    },
    FactoryPreset {
        name: "06 Rock Vocal",
        archive_sha256: "28b82940392ffd8cffdadc10343c9402f762e69cd049b1212233cee196409544",
        values: [0.0, 0.5, 0.45833334, 0.55, 1.0, 0.0, 0.0],
    },
    FactoryPreset {
        name: "07 Small Chorus",
        archive_sha256: "1d5c068291c4464fd880c35b6822d71142aa8fb9fee6ed96cf6690746ccaf6d9",
        values: [0.0, 0.5, 0.5, 0.31, 0.44, 1.0, 0.0],
    },
    FactoryPreset {
        name: "08 High Octave Double",
        archive_sha256: "2ce292586d4ade7454edfb73ad1a94a2c056fbf1f85ca676f21af046090b74b0",
        values: [0.0, 1.0, 0.56666666, 0.0, 0.495, 0.0, 0.0],
    },
    FactoryPreset {
        name: "09 Low Octave Double",
        archive_sha256: "da1b1aa8d6cd31eaf072883ae6e88d106bc5f773a993dd4d7cea67c9b7cfdb22",
        values: [0.0, 0.0, 0.14166667, 0.0, 0.34, 0.0, 0.0],
    },
    FactoryPreset {
        name: "10 Octave Down Classic DJ",
        archive_sha256: "f2971dab493ff32f3dd378b92c916231d0829d4132648749480fe958b4cd1aff",
        values: [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0],
    },
    FactoryPreset {
        name: "11 Robotic",
        archive_sha256: "f31e1e1b136b3464e7241285f57bbb4e770efeada63557ddde6a52779bd44745",
        values: [0.0, 0.5, 0.5, 0.11, 1.0, 2.0, 0.0],
    },
    FactoryPreset {
        name: "Default",
        archive_sha256: "4dbf5db23d72b18214b4add0fcbd82627637781daeec37de4db58c849a8c45f3",
        values: [0.0, 0.5, 0.5, 0.0, 1.0, 0.0, 0.0],
    },
];
