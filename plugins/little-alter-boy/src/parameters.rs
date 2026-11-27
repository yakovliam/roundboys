#[derive(Clone, Copy, Debug)]
pub struct Parameter {
    pub id: u32,
    pub name: &'static str,
    pub maximum: f32,
    pub default: f32,
    pub discrete: bool,
}
pub const PARAMETERS: [Parameter; 7] = [
    Parameter {
        id: 7,
        name: "Bypass",
        maximum: 1.,
        default: 0.0,
        discrete: true,
    },
    Parameter {
        id: 8,
        name: "Pitch",
        maximum: 1.,
        default: 0.5,
        discrete: false,
    },
    Parameter {
        id: 9,
        name: "Formant",
        maximum: 1.,
        default: 0.5,
        discrete: false,
    },
    Parameter {
        id: 10,
        name: "Drive",
        maximum: 1.,
        default: 0.0,
        discrete: false,
    },
    Parameter {
        id: 11,
        name: "Mix",
        maximum: 1.,
        default: 1.0,
        discrete: false,
    },
    Parameter {
        id: 12,
        name: "ShiftMode",
        maximum: 2.,
        default: 0.0,
        discrete: true,
    },
    Parameter {
        id: 13,
        name: "FormantLink",
        maximum: 1.,
        default: 0.0,
        discrete: true,
    },
];
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Parameters {
    pub(crate) values: [f32; 7],
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
        if !value.is_finite() || !(0.0..=PARAMETERS[i].maximum).contains(&value) {
            return Err("Invalid parameter value");
        }
        // Preserve the public host range. The editor uses integer mode choices.
        self.values[i] = value;
        Ok(())
    }
    pub fn encode(self) -> [u8; 36] {
        let mut data = [0; 36];
        data[..8].copy_from_slice(b"LASTATE1");
        for (i, v) in self.values.iter().enumerate() {
            data[8 + i * 4..12 + i * 4].copy_from_slice(&v.to_le_bytes());
        }
        data
    }
    pub fn decode(data: &[u8]) -> Result<Self, &'static str> {
        if data.len() != 36 || &data[..8] != b"LASTATE1" {
            return Err("Invalid state version or length");
        }
        let mut out = Self::default();
        for (i, p) in PARAMETERS.iter().enumerate() {
            out.set(
                p.id,
                f32::from_le_bytes(data[8 + i * 4..12 + i * 4].try_into().unwrap()),
            )?;
        }
        Ok(out)
    }
}
