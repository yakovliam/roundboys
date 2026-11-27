use std::f64::consts::{PI, TAU};
pub const SIZE: usize = 2048;
pub const HOP: usize = 256;
const BINS: usize = SIZE / 2 + 1;
#[derive(Clone, Copy, Default)]
struct Complex {
    re: f64,
    im: f64,
}
pub struct Fourier {
    roots: Vec<Complex>,
    reversed: Vec<usize>,
    window: Vec<f64>,
}
impl Fourier {
    pub fn new() -> Self {
        Self {
            roots: (0..SIZE / 2)
                .map(|i| {
                    let angle = -TAU * i as f64 / SIZE as f64;
                    Complex {
                        re: angle.cos(),
                        im: angle.sin(),
                    }
                })
                .collect(),
            reversed: (0..SIZE)
                .map(|i| i.reverse_bits() >> (usize::BITS - SIZE.ilog2()))
                .collect(),
            window: (0..SIZE)
                .map(|i| 0.5 - 0.5 * (TAU * i as f64 / SIZE as f64).cos())
                .collect(),
        }
    }
    fn transform(&self, data: &mut [Complex], inverse: bool) {
        for i in 0..SIZE {
            let j = self.reversed[i];
            if j > i {
                data.swap(i, j)
            }
        }
        let mut width = 2;
        while width <= SIZE {
            for start in (0..SIZE).step_by(width) {
                for j in 0..width / 2 {
                    let root = self.roots[j * SIZE / width];
                    let sign = if inverse { -1. } else { 1. };
                    let b = data[start + j + width / 2];
                    let a = data[start + j];
                    let re = b.re * root.re - b.im * root.im * sign;
                    let im = b.re * root.im * sign + b.im * root.re;
                    data[start + j] = Complex {
                        re: a.re + re,
                        im: a.im + im,
                    };
                    data[start + j + width / 2] = Complex {
                        re: a.re - re,
                        im: a.im - im,
                    };
                }
            }
            width *= 2;
        }
        if inverse {
            for x in data {
                x.re /= SIZE as f64;
                x.im /= SIZE as f64;
            }
        }
    }
}
pub struct Channel {
    input: Vec<f64>,
    output: Vec<f64>,
    dry: Vec<f32>,
    work: Vec<Complex>,
    previous: Vec<f64>,
    phase: Vec<f64>,
    magnitude: Vec<f64>,
    frequency: Vec<f64>,
    envelope: Vec<f64>,
    prefix: Vec<f64>,
    mapped: Vec<f64>,
    mapped_frequency: Vec<f64>,
}
impl Channel {
    pub fn clear(&mut self) {
        self.input.fill(0.);
        self.output.fill(0.);
        self.dry.fill(0.);
        self.work.fill(Complex::default());
        self.previous.fill(0.);
        self.phase.fill(0.);
        self.magnitude.fill(0.);
        self.frequency.fill(0.);
        self.envelope.fill(0.);
        self.prefix.fill(0.);
        self.mapped.fill(0.);
        self.mapped_frequency.fill(0.);
    }
    pub fn new() -> Self {
        Self {
            input: vec![0.; SIZE],
            output: vec![0.; SIZE * 2],
            dry: vec![0.; SIZE],
            work: vec![Complex::default(); SIZE],
            previous: vec![0.; BINS],
            phase: vec![0.; BINS],
            magnitude: vec![0.; BINS],
            frequency: vec![0.; BINS],
            envelope: vec![0.; BINS],
            prefix: vec![0.; BINS + 1],
            mapped: vec![0.; BINS],
            mapped_frequency: vec![0.; BINS],
        }
    }
    pub fn sample(&mut self, input: f32, position: usize) -> (f32, f32) {
        let index = position % SIZE;
        let dry = self.dry[index];
        self.dry[index] = input;
        self.input[index] = input as f64;
        let index = position % (SIZE * 2);
        let wet = self.output[index] as f32;
        self.output[index] = 0.;
        (dry, wet)
    }
    pub fn fundamental(&self, position: usize, rate: f64) -> Option<f64> {
        let start = (position + 1) % SIZE;
        let sample = |i: usize| self.input[(start + i * 4) % SIZE];
        let count = SIZE / 4;
        let minimum = (rate / 4. / 1000.).max(2.) as usize;
        let maximum = ((rate / 4. / 65.) as usize).min(count / 2 - 1);
        let correlation = |lag: usize| {
            let (mut sum, mut a, mut b) = (0., 0., 0.);
            for i in 0..count - maximum {
                let x = sample(i);
                let y = sample(i + lag);
                sum += x * y;
                a += x * x;
                b += y * y;
            }
            sum / (a * b).sqrt().max(1e-12)
        };
        let mut previous = correlation(minimum);
        let mut rising = false;
        for lag in minimum + 1..=maximum {
            let value = correlation(lag);
            if rising && value < previous && previous > 0.72 {
                return Some(rate / 4. / (lag - 1) as f64);
            }
            rising = value > previous;
            previous = value;
        }
        None
    }
    pub fn frame(&mut self, fft: &Fourier, position: usize, pitch: f64, formant: f64, rate: f64) {
        let start = (position + 1) % SIZE;
        for i in 0..SIZE {
            self.work[i] = Complex {
                re: self.input[(start + i) % SIZE] * fft.window[i],
                im: 0.,
            };
        }
        fft.transform(&mut self.work, false);
        for k in 0..BINS {
            let c = self.work[k];
            let phase = c.im.atan2(c.re);
            let omega = TAU * k as f64 / SIZE as f64;
            let delta = (phase - self.previous[k] - omega * HOP as f64 + PI).rem_euclid(TAU) - PI;
            self.previous[k] = phase;
            self.magnitude[k] = (c.re * c.re + c.im * c.im).sqrt();
            self.frequency[k] = omega + delta / HOP as f64;
        }
        if (pitch - 1.).abs() > 1e-7 || (formant - 1.).abs() > 1e-7 {
            self.prefix[0] = 0.;
            for k in 0..BINS {
                self.prefix[k + 1] = self.prefix[k] + self.magnitude[k].max(1e-8).ln();
            }
            let radius = (250. * SIZE as f64 / rate).round().max(3.) as usize;
            for k in 0..BINS {
                let low = k.saturating_sub(radius);
                let high = (k + radius + 1).min(BINS);
                self.envelope[k] = (self.prefix[high] - self.prefix[low]) / (high - low) as f64;
            }
            self.mapped.fill(0.);
            self.mapped_frequency.fill(0.);
            for k in 1..BINS - 1 {
                let destination = k as f64 * pitch;
                let lower = destination.floor() as usize;
                let fraction = destination.fract();
                for (bin, weight) in [(lower, 1. - fraction), (lower + 1, fraction)] {
                    if bin > 0 && bin < BINS - 1 {
                        let amount = self.magnitude[k] * weight;
                        self.mapped[bin] += amount;
                        self.mapped_frequency[bin] += amount * self.frequency[k] * pitch;
                    }
                }
            }
            let interpolate = |x: f64| {
                let x = x.clamp(0., (BINS - 1) as f64);
                let i = x.floor() as usize;
                self.envelope[i]
                    + x.fract() * (self.envelope[(i + 1).min(BINS - 1)] - self.envelope[i])
            };
            for k in 1..BINS - 1 {
                let frequency = if self.mapped[k] > 1e-12 {
                    self.mapped_frequency[k] / self.mapped[k]
                } else {
                    TAU * k as f64 / SIZE as f64
                };
                self.phase[k] = (self.phase[k] + frequency * HOP as f64).rem_euclid(TAU);
                let correction = (interpolate(k as f64 / formant) - interpolate(k as f64 / pitch))
                    .clamp(-3., 3.)
                    .exp();
                let amplitude = self.mapped[k] * correction;
                self.work[k] = Complex {
                    re: amplitude * self.phase[k].cos(),
                    im: amplitude * self.phase[k].sin(),
                };
                self.work[SIZE - k] = Complex {
                    re: self.work[k].re,
                    im: -self.work[k].im,
                };
            }
            self.work[0] = Complex::default();
            self.work[SIZE / 2] = Complex::default();
        } else {
            self.phase.copy_from_slice(&self.previous);
        }
        fft.transform(&mut self.work, true);
        for i in 0..SIZE {
            self.output[(position + 1 + i) % (SIZE * 2)] += self.work[i].re * fft.window[i] / 3.;
        }
    }
}
