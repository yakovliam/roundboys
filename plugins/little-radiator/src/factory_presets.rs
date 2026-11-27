//! Observed factory control values. Archive hashes identify exact checked presets.
//! Source evidence: evaluation/reimplementation/little-radiator/presets/factory-20261126T060848831395Z/summary.json
pub struct FactoryPreset {
    pub name: &'static str,
    pub archive_sha256: &'static str,
    pub values: [f32; 5],
}
pub const FACTORY_PRESETS: [FactoryPreset; 14] = [
    FactoryPreset {
        name: "Acoustic Tamer",
        archive_sha256: "c0cee978666fa83a5f26b863a0658d4955b2a65ca305ddae4efc830bb0bd4551",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3ed1eb85),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Bass Beef",
        archive_sha256: "3ac2f064b3f9d738d0ba2e81552eccb9afdbd3eb4abbee81a2a8b70ee26385b3",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f3d70a4),
            f32::from_bits(0x3f000000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Bass Bite",
        archive_sha256: "8ac8383df2f5ac7e86fa81ec74ff8861c172e4b0d7059997171d12a63c0b033b",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f19999a),
            f32::from_bits(0x3f5eb852),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Bit of Grit",
        archive_sha256: "d0799169114868b5cf1a1d6d0e772521e443626b819738ecf1adaadce2a4913f",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f428f5c),
            f32::from_bits(0x3f000000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Default",
        archive_sha256: "63b312c1e9aeef69afbf623a84af5852bda91746a99afbd61919cb72371fd588",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f000000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Getting Warmer",
        archive_sha256: "dc97cf11c58ef5c169d85ada4803ba138565f66c3c8f3d3b8fca3d73d0d832ed",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f251eb8),
            f32::from_bits(0x3f28f5c3),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Guitar Double Edge",
        archive_sha256: "54279ac52ec5231ff5ca0099e2823ac18fc79aa9813f9acef6a2f89497248cff",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3e051eb8),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Hot Tip",
        archive_sha256: "83a0e858d1181c1875f57568c3814cdcf9581e9bec4474ca369922888469e376",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f6b851f),
            f32::from_bits(0x3d8f5c29),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Luke Warm",
        archive_sha256: "c8228f82f7fefd5a80c650bb02ab6b32bf00dea441555f34b47b5ca8cdc2aab6",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f11eb85),
            f32::from_bits(0x3f147ae1),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Rhodes Toaster",
        archive_sha256: "28c29a7bd6e4109194d6e108d9503793b9a817ec481ee182efb23f078f8ea44a",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f08f5c3),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "TakeTheChillOff",
        archive_sha256: "e470c2a934f65b446b0193b5c3ab5194aaa7a1c1112cd15bcd9c76c859474bb2",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3ea147ae),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Tasteful",
        archive_sha256: "c9f35e0278f7710a53a32cd740aaa10d4eb7b6c47354a86c93f94ca7872bef07",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f27ae14),
            f32::from_bits(0x3f000000),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Touch of Tube",
        archive_sha256: "15887086bb65ea78c32c116de83864897f306e254a4148dbf4071ebdbf63e8d0",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f028f5c),
            f32::from_bits(0x3db851ec),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3f800000),
        ],
    },
    FactoryPreset {
        name: "Vocal OverHeated",
        archive_sha256: "df7375fbc224e8b18dca568ce4be3e1ceed12a73200ef609f6c1588decb3875a",
        values: [
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
            f32::from_bits(0x3ec28f5c),
            f32::from_bits(0x00000000),
            f32::from_bits(0x3f800000),
        ],
    },
];
