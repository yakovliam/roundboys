use little_radiator::{Parameters, Processor};
use std::{
    error::Error,
    fs::File,
    io::{BufWriter, Write},
};
fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(2);
    }
}
fn run() -> Result<(), Box<dyn Error>> {
    let a: Vec<_> = std::env::args().skip(1).collect();
    if a.len() != 10 {
        return Err(
            "Usage: render output rate frames block signal heat mix noise bias bypass".into(),
        );
    }
    let rate: f64 = a[1].parse()?;
    let frames: usize = a[2].parse()?;
    let block: usize = a[3].parse()?;
    let signal: u8 = a[4].parse()?;
    let mut processor = Processor::new(rate)?;
    if frames == 0 || frames as f64 > rate * 120. || !(1..=4096).contains(&block) || signal > 3 {
        return Err("Invalid render input".into());
    }
    let mut parameters = Parameters::default();
    for (id, value) in [8, 9, 12, 10, 7].into_iter().zip(&a[5..]) {
        parameters.set(id, value.parse()?)?;
    }
    let mut output = BufWriter::new(File::create(&a[0])?);
    let mut left = vec![0.; block];
    let mut right = vec![0.; block];
    for start in (0..frames).step_by(block) {
        let count = block.min(frames - start);
        for i in 0..count {
            let index = start + i;
            let time = index as f64 / rate;
            let sample = match signal {
                1 => {
                    if index == 0 {
                        0.1
                    } else {
                        0.
                    }
                }
                2 => 0.1 * (std::f64::consts::TAU * 440. * time).sin(),
                3 => 0.1 * (std::f64::consts::TAU * (20. * time + 4000. * time * time)).sin(),
                _ => 0.,
            };
            left[i] = sample as f32;
            right[i] = sample as f32;
        }
        processor.process(&mut left[..count], &mut right[..count], parameters)?;
        for (l, r) in left[..count].iter().zip(&right[..count]) {
            output.write_all(&l.to_le_bytes())?;
            output.write_all(&r.to_le_bytes())?;
        }
    }
    output.flush()?;
    Ok(())
}
