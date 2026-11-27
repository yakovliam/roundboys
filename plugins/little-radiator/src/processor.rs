use crate::Parameters;
/// Provisional latency from the settled 48 kHz dry-tone fixture. Other rates
/// and original automation timing remain unmeasured. This model uses 48 frames.
pub const LATENCY: usize = 48;
/// A replaceable wet model. Gain, filtering, noise, and smoothing are design
/// choices pending identification. Do not use this model as a reference oracle.
pub struct Processor {
    rate: f64,
    delay: [[f32; LATENCY]; 2],
    cursor: usize,
    smooth: [f32; 5],
    smoothing: f32,
    low: [f32; 2],
    dc_x: [f32; 2],
    dc_y: [f32; 2],
    seeds: [u32; 2],
}
impl Processor {
    pub fn new(rate: f64) -> Result<Self, &'static str> {
        if !rate.is_finite() || !(8000.0..=192000.0).contains(&rate) {
            return Err("Unsupported sample rate");
        }
        Ok(Self {
            rate,
            delay: [[0.; LATENCY]; 2],
            cursor: 0,
            smooth: [0., 0.5, 1., 0., 1.],
            smoothing: (1. - (-1. / (0.02 * rate)).exp()) as f32,
            low: [0.; 2],
            dc_x: [0.; 2],
            dc_y: [0.; 2],
            seeds: [0x12345678, 0x87654321],
        })
    }
    pub fn reset(&mut self) {
        *self = Self::new(self.rate).unwrap();
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
        let target = [7, 8, 9, 10, 12].map(|id| target.get(id).unwrap());
        let lp = (1. - (-std::f64::consts::TAU * 12000. / self.rate).exp()) as f32;
        let hp = (-std::f64::consts::TAU * 8. / self.rate).exp() as f32;
        for (l, r) in left.iter_mut().zip(right) {
            for (s, t) in self.smooth.iter_mut().zip(target) {
                *s += self.smoothing * (t - *s);
            }
            let [bypass, heat, mix, bias, noise] = self.smooth;
            let gain = 10.0_f32.powf((-11.2 + 30.2 * heat) / 20.);
            let offset = 0.18 * bias;
            let wet_mix = mix * (1. - bypass);
            for (channel, output) in [l, r].into_iter().enumerate() {
                let input = if output.is_finite() { *output } else { 0. };
                let dry = self.delay[channel][self.cursor];
                self.delay[channel][self.cursor] = input;
                let mut seed = self.seeds[channel];
                seed ^= seed << 13;
                seed ^= seed >> 17;
                seed ^= seed << 5;
                self.seeds[channel] = seed;
                let n = (seed as f64 / u32::MAX as f64 * 2. - 1.) as f32 * 0.00032 * noise;
                let tube = (dry * gain + offset).tanh() - offset.tanh() + n;
                self.low[channel] += lp * (tube - self.low[channel]);
                let wet = self.low[channel] - self.dc_x[channel] + hp * self.dc_y[channel];
                self.dc_x[channel] = self.low[channel];
                self.dc_y[channel] = wet;
                *output = dry + wet_mix * (wet - dry);
            }
            self.cursor = (self.cursor + 1) % LATENCY;
        }
        Ok(())
    }
}
