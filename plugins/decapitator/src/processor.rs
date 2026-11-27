use crate::Parameters;
pub const LATENCY: usize = 62;
/// Independent development model. These five curves are not recovered circuits.
/// Filter mappings, gain compensation, and 4x interpolation are provisional.
pub struct Processor {
    rate: f64,
    meter_power: f32,
    meter_coefficient: f32,
    delay: [[f32; LATENCY]; 2],
    cursor: usize,
    smoothed: [f32; 12],
    coefficient: f32,
    low: [f32; 2],
    high: [[f32; 2]; 2],
    tone: [f32; 2],
    previous: [f32; 2],
    dc_in: [f32; 2],
    dc_out: [f32; 2],
}
impl Processor {
    pub fn new(rate: f64) -> Result<Self, &'static str> {
        if !rate.is_finite() || !(8000.0..=192000.0).contains(&rate) {
            return Err("Unsupported sample rate");
        }
        Ok(Self {
            rate,
            meter_power: 0.0,
            meter_coefficient: (1.0 - (-1.0 / (0.150 * rate)).exp()) as f32,
            delay: [[0.; LATENCY]; 2],
            cursor: 0,
            smoothed: Parameters::default().values,
            coefficient: (1. - (-1. / (0.02 * rate)).exp()) as f32,
            low: [0.; 2],
            high: [[0.; 2]; 2],
            tone: [0.; 2],
            previous: [0.; 2],
            dc_in: [0.; 2],
            dc_out: [0.; 2],
        })
    }
    pub fn reset(&mut self) {
        *self = Self::new(self.rate).unwrap();
    }
    /// Provisional output RMS, referenced to -6 dBFS = 0 VU.
    pub fn meter_db(&self) -> f32 {
        if self.meter_power < 1e-12 {
            -60.0
        } else {
            (10.0 * self.meter_power.log10() + 6.0).max(-60.0)
        }
    }
    fn curve(x: f32, style: usize) -> f32 {
        match style {
            0 => x.tanh(),
            1 => x / (1. + x.abs()),
            2 => (x + 0.16).tanh() - 0.16_f32.tanh(),
            3 => x.atan() * std::f32::consts::FRAC_2_PI,
            _ => x / (1. + x * x).sqrt(),
        }
    }
    pub fn process(
        &mut self,
        left: &mut [f32],
        right: &mut [f32],
        target: Parameters,
    ) -> Result<(), &'static str> {
        if left.len() != right.len() {
            return Err("Channel lengths differ");
        }
        let tone_coefficient = (1. - (-std::f64::consts::TAU * 900. / self.rate).exp()) as f32;
        let dc_coefficient = (-std::f64::consts::TAU * 5. / self.rate).exp() as f32;
        for (l, r) in left.iter_mut().zip(right) {
            for (s, t) in self.smoothed.iter_mut().zip(target.values) {
                *s += self.coefficient * (t - *s);
                if (t - *s).abs() < (f32::EPSILON * t.abs().max(1.0) / self.coefficient).max(1e-5) {
                    *s = t;
                }
            }
            let p = self.smoothed;
            let style = target.values[1].round() as usize;
            let gain = 10f32.powf((30. * p[2] + 20. * p[3]) / 20.);
            let compensation = gain.powf(-0.55 * p[8]);
            let low_coefficient = (1.
                - (-std::f64::consts::TAU * (20. * 50f64.powf(p[4] as f64)).min(self.rate * 0.45)
                    / self.rate)
                    .exp()) as f32;
            let high_coefficient = (1.
                - (-std::f64::consts::TAU
                    * (1000. * 20f64.powf(p[6] as f64)).min(self.rate * 0.45)
                    / self.rate)
                    .exp()) as f32;
            let mut output_power = 0.0f32;
            for (c, out) in [l, r].into_iter().enumerate() {
                let input = if out.is_finite() { *out } else { 0. };
                let dry = self.delay[c][self.cursor];
                self.delay[c][self.cursor] = input;
                self.low[c] += low_coefficient * (dry - self.low[c]);
                let filtered = if p[4] > 1e-5 {
                    dry - self.low[c] + p[9] * self.low[c] * 0.65
                } else {
                    dry + p[9] * self.low[c] * 0.65
                };
                let mut wet = 0.;
                for phase in 1..=4 {
                    let x =
                        self.previous[c] + (filtered - self.previous[c]) * (phase as f32 * 0.25);
                    wet += Self::curve(x * gain, style) * 0.25;
                }
                self.previous[c] = filtered;
                wet *= compensation;
                self.tone[c] += tone_coefficient * (wet - self.tone[c]);
                let tilt = (p[5] - 0.5) * 2.;
                wet = self.tone[c] * 10f32.powf(-tilt * 6. / 20.)
                    + (wet - self.tone[c]) * 10f32.powf(tilt * 6. / 20.);
                self.high[c][0] += high_coefficient * (wet - self.high[c][0]);
                self.high[c][1] += high_coefficient * (self.high[c][0] - self.high[c][1]);
                if p[6] < 0.99999 {
                    wet = self.high[c][0] * (1. - p[10]) + self.high[c][1] * p[10];
                }
                let dc = wet - self.dc_in[c] + dc_coefficient * self.dc_out[c];
                self.dc_in[c] = wet;
                self.dc_out[c] = dc;
                wet = dc * p[11];
                let blend = p[7] * (1. - p[0]);
                *out = dry + blend * (wet - dry);
                output_power += out.powi(2) * 0.5;
            }
            self.meter_power += self.meter_coefficient * (output_power - self.meter_power);
            self.cursor = (self.cursor + 1) % LATENCY;
        }
        Ok(())
    }
}
