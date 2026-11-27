use crate::{
    Parameters,
    spectral::{Channel, Fourier, HOP, SIZE},
};
pub const LATENCY: usize = SIZE;
#[derive(Clone, Copy, Default)]
struct Midi {
    status: u8,
    note: u8,
    velocity: u8,
    offset: usize,
}
/// Independent phase-vocoder model. Original DSP matching remains open.
pub struct Processor {
    rate: f64,
    fft: Fourier,
    channels: [Channel; 2],
    position: usize,
    smoothed: [f32; 7],
    coefficient: f32,
    fundamental: f64,
    events: [Midi; 128],
    event_count: usize,
    notes: [u8; 128],
    note: u8,
}
impl Processor {
    pub fn new(rate: f64) -> Result<Self, &'static str> {
        if !rate.is_finite() || !(8000. ..=192000.).contains(&rate) {
            return Err("Unsupported sample rate");
        }
        Ok(Self {
            rate,
            fft: Fourier::new(),
            channels: [Channel::new(), Channel::new()],
            position: 0,
            smoothed: Parameters::default().values,
            coefficient: (1. - (-1. / (0.02 * rate)).exp()) as f32,
            fundamental: 110.,
            events: [Midi::default(); 128],
            event_count: 0,
            notes: [0; 128],
            note: 60,
        })
    }
    pub fn reset(&mut self) {
        // Reuse all allocated storage when the host resets an initialized unit.
        for channel in &mut self.channels {
            channel.clear();
        }
        self.position = 0;
        self.smoothed = Parameters::default().values;
        self.fundamental = 110.;
        self.event_count = 0;
        self.notes.fill(0);
        self.note = 60;
    }
    pub fn midi(
        &mut self,
        status: u8,
        note: u8,
        velocity: u8,
        offset: usize,
    ) -> Result<(), &'static str> {
        if self.event_count == 128 || note > 127 || velocity > 127 {
            return Err("Invalid or full MIDI queue");
        }
        self.events[self.event_count] = Midi {
            status,
            note,
            velocity,
            offset,
        };
        self.event_count += 1;
        Ok(())
    }
    pub fn process(
        &mut self,
        left: &mut [f32],
        right: &mut [f32],
        parameters: Parameters,
    ) -> Result<(), &'static str> {
        if left.len() != right.len() {
            return Err("Channel lengths differ");
        }
        let frames = left.len();
        for (sample, (left, right)) in left.iter_mut().zip(right).enumerate() {
            for index in 0..self.event_count {
                let event = self.events[index];
                if event.offset != sample {
                    continue;
                }
                match event.status & 0xf0 {
                    0x90 if event.velocity > 0 => {
                        self.notes[event.note as usize] = event.velocity;
                        self.note = event.note;
                    }
                    0x80 | 0x90 => {
                        self.notes[event.note as usize] = 0;
                        if self.note == event.note
                            && let Some(n) = self.notes.iter().rposition(|v| *v > 0)
                        {
                            self.note = n as u8;
                        }
                    }
                    0xb0 if event.note == 120 || event.note == 123 => self.notes.fill(0),
                    _ => {}
                }
            }
            for (i, value) in self.smoothed.iter_mut().enumerate() {
                *value += self.coefficient * (parameters.values[i] - *value);
                if (*value - parameters.values[i]).abs() < 1e-6 {
                    *value = parameters.values[i];
                }
            }
            for (channel, out) in self.channels.iter_mut().zip([left, right]) {
                let input = if out.is_finite() { *out } else { 0. };
                let (dry, wet) = channel.sample(input, self.position);
                let drive = self.smoothed[3];
                let gain = 1. + 31. * drive;
                let wet = if drive > 1e-6 {
                    (wet * gain).tanh() / gain.sqrt()
                } else {
                    wet
                };
                let mix = self.smoothed[4] * (1. - self.smoothed[0]);
                *out = dry + mix * (wet - dry);
            }
            if (self.position + 1).is_multiple_of(HOP) {
                let mode = parameters.values[5].round() as usize;
                if mode > 0
                    && let Some(f) = self.channels[0].fundamental(self.position, self.rate)
                {
                    self.fundamental = f;
                }
                let semitones = 24. * (self.smoothed[1] as f64 - 0.5);
                let mut pitch = 2f64.powf(semitones / 12.);
                if mode == 1 {
                    let note = 69. + 12. * (self.fundamental / 440.).log2();
                    pitch *= 2f64.powf((note.round() - note) / 12.);
                }
                if mode == 2 {
                    let note = if self.notes.iter().any(|v| *v > 0) {
                        self.note as f64
                    } else {
                        60.
                    };
                    pitch = 440. * 2f64.powf((note - 69. + semitones) / 12.) / self.fundamental;
                }
                let formant = 2f64.powf(24. * (self.smoothed[2] as f64 - 0.5) / 12.);
                for channel in &mut self.channels {
                    channel.frame(
                        &self.fft,
                        self.position,
                        pitch.clamp(0.125, 8.),
                        formant,
                        self.rate,
                    );
                }
            }
            self.position = (self.position + 1) % (SIZE * 2);
        }
        let mut remaining = 0;
        for index in 0..self.event_count {
            let mut event = self.events[index];
            if event.offset >= frames {
                event.offset -= frames;
                self.events[remaining] = event;
                remaining += 1;
            }
        }
        self.event_count = remaining;
        Ok(())
    }
}
