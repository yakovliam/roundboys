#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Parameter {
    pub id: u32,
    pub name: &'static str,
    pub default: f32,
    pub toggle: bool,
}
pub const PARAMETERS: [Parameter; 5] = [
    Parameter {
        id: 7,
        name: "Bypass",
        default: 0.,
        toggle: true,
    },
    Parameter {
        id: 8,
        name: "Heat",
        default: 0.5,
        toggle: false,
    },
    Parameter {
        id: 9,
        name: "Mix",
        default: 1.,
        toggle: false,
    },
    Parameter {
        id: 10,
        name: "Bias",
        default: 0.,
        toggle: true,
    },
    Parameter {
        id: 12,
        name: "Noise",
        default: 1.,
        toggle: true,
    },
];
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Parameters {
    values: [f32; 5],
}
impl Default for Parameters {
    fn default() -> Self {
        Self {
            values: PARAMETERS.map(|p| p.default),
        }
    }
}
impl Parameters {
    pub fn get(self, id: u32) -> Option<f32> {
        PARAMETERS
            .iter()
            .position(|p| p.id == id)
            .map(|i| self.values[i])
    }
    pub fn set(&mut self, id: u32, value: f32) -> Result<(), &'static str> {
        let i = PARAMETERS
            .iter()
            .position(|p| p.id == id)
            .ok_or("Unknown parameter")?;
        if !value.is_finite() || !(0.0..=1.0).contains(&value) {
            return Err("Parameter is outside 0..1");
        }
        self.values[i] = value;
        Ok(())
    }
    // This is our format, not the original AU state or .toy archive format.
    pub fn encode(self) -> [u8; 28] {
        let mut bytes = [0; 28];
        bytes[..8].copy_from_slice(b"LRSTATE1");
        for (i, value) in self.values.iter().enumerate() {
            bytes[8 + i * 4..12 + i * 4].copy_from_slice(&value.to_le_bytes());
        }
        bytes
    }
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() != 28 || &bytes[..8] != b"LRSTATE1" {
            return Err("Invalid state version or length");
        }
        let mut p = Self::default();
        for (i, meta) in PARAMETERS.iter().enumerate() {
            p.set(
                meta.id,
                f32::from_le_bytes(bytes[8 + i * 4..12 + i * 4].try_into().unwrap()),
            )?;
        }
        Ok(p)
    }
}
