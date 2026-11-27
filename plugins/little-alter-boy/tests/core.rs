use little_alter_boy::{Parameters, Processor};
const RATE: f64 = 48000.;
fn tone(frequency: f64, count: usize) -> Vec<f32> {
    (0..count)
        .map(|i| (std::f64::consts::TAU * frequency * i as f64 / RATE).sin() as f32 * 0.1)
        .collect()
}
fn power(signal: &[f32], frequency: f64) -> f64 {
    let (mut re, mut im) = (0., 0.);
    for (i, x) in signal.iter().enumerate() {
        let phase = std::f64::consts::TAU * frequency * i as f64 / RATE;
        re += *x as f64 * phase.cos();
        im += *x as f64 * phase.sin();
    }
    re * re + im * im
}
#[test]
fn neutral_audio_and_dry_paths_keep_the_declared_delay() {
    let original = tone(440., 48000);
    for (id, value) in [(7, 0.), (7, 1.), (11, 0.)] {
        let mut parameters = Parameters::default();
        parameters.set(id, value).unwrap();
        let mut processor = Processor::new(RATE).unwrap();
        let mut left = original.clone();
        let mut right = original.clone();
        processor
            .process(&mut left, &mut right, parameters)
            .unwrap();
        for i in 0..left.len() {
            let expected = if i < 2048 { 0. } else { original[i - 2048] };
            assert!(
                (left[i] - expected).abs() < 2e-6,
                "sample {i}: {} vs {expected}",
                left[i]
            );
            assert_eq!(left[i], right[i]);
        }
        processor.reset();
        let mut silence = vec![0.; 4096];
        let mut right = silence.clone();
        processor
            .process(&mut silence, &mut right, parameters)
            .unwrap();
        assert!(silence.iter().all(|x| *x == 0.));
    }
}
#[test]
fn transpose_moves_a_tone_one_octave() {
    for (normalized, frequency) in [(0., 220.), (1., 880.)] {
        let mut parameters = Parameters::default();
        parameters.set(8, normalized).unwrap();
        let mut processor = Processor::new(RATE).unwrap();
        let mut left = tone(440., 96000);
        let mut right = left.clone();
        processor
            .process(&mut left, &mut right, parameters)
            .unwrap();
        let tail = &left[48000..];
        assert!(
            power(tail, frequency) > power(tail, 440.) * 20.,
            "pitch {normalized} does not move the tone"
        );
        assert!(tail.iter().all(|x| x.is_finite()));
    }
}
#[test]
fn robot_uses_midi_note_and_note_queue_is_bounded() {
    let mut parameters = Parameters::default();
    parameters.set(12, 2.).unwrap();
    let mut processor = Processor::new(RATE).unwrap();
    processor.midi(0x90, 69, 100, 0).unwrap();
    let mut left = tone(220., 96000);
    let mut right = left.clone();
    processor
        .process(&mut left, &mut right, parameters)
        .unwrap();
    let tail = &left[48000..];
    assert!(power(tail, 440.) > power(tail, 220.) * 20.);
    for _ in 0..128 {
        processor.midi(0x80, 69, 0, 0).unwrap();
    }
    assert!(processor.midi(0x80, 69, 0, 0).is_err());
}
#[test]
fn state_validation_and_processing_are_block_independent() {
    let mut parameters = Parameters::default();
    parameters.set(8, 0.75).unwrap();
    parameters.set(9, 0.3).unwrap();
    assert_eq!(
        parameters,
        Parameters::decode(&parameters.encode()).unwrap()
    );
    assert!(parameters.set(12, 3.).is_err());
    assert!(parameters.set(8, f32::NAN).is_err());
    let mut outputs = Vec::new();
    for block in [64, 256, 1024] {
        let mut processor = Processor::new(RATE).unwrap();
        let mut left = tone(330., 24000);
        let mut right = left.clone();
        for (l, r) in left.chunks_mut(block).zip(right.chunks_mut(block)) {
            processor.process(l, r, parameters).unwrap();
        }
        outputs.push(left);
    }
    assert_eq!(outputs[0], outputs[1]);
    assert_eq!(outputs[0], outputs[2]);
}
#[test]
fn modes_formants_and_sample_rates_remain_finite() {
    for rate in [44100., 48000., 96000.] {
        for mode in 0..3 {
            for formant in [0., 1.] {
                let mut parameters = Parameters::default();
                parameters.set(12, mode as f32).unwrap();
                parameters.set(9, formant).unwrap();
                parameters.set(10, 1.).unwrap();
                let mut processor = Processor::new(rate).unwrap();
                let mut left = tone(220., 8192);
                left[1] = f32::NAN;
                let mut right = left.clone();
                processor
                    .process(&mut left, &mut right, parameters)
                    .unwrap();
                assert!(left.iter().all(|x| x.is_finite()));
            }
        }
    }
}

#[test]
fn quantize_and_default_robot_choose_the_target_notes() {
    for (mode, input, expected) in [(1., 435., 440.), (2., 220., 261.626)] {
        let mut parameters = Parameters::default();
        parameters.set(12, mode).unwrap();
        let mut processor = Processor::new(RATE).unwrap();
        let mut left = tone(input, 96000);
        let mut right = left.clone();
        processor
            .process(&mut left, &mut right, parameters)
            .unwrap();
        let tail = &left[48000..];
        let peak = (-12..=12)
            .map(|step| expected + step as f64 * 0.25)
            .max_by(|a, b| power(tail, *a).total_cmp(&power(tail, *b)))
            .unwrap();
        assert!(
            (peak - expected).abs() <= 0.5,
            "mode {mode}: {peak} vs {expected}"
        );
        assert!(power(tail, peak) > power(tail, input) * 20.);
    }
}

#[test]
fn formant_moves_the_spectral_envelope_without_changing_pitch() {
    let voice: Vec<f32> = (0..96000)
        .map(|i| {
            (1..30)
                .map(|harmonic| {
                    let frequency = 100. * harmonic as f64;
                    let envelope = (-0.5 * ((frequency - 700.) / 160.).powi(2)).exp()
                        + 0.5 * (-0.5 * ((frequency - 1500.) / 250.).powi(2)).exp();
                    (std::f64::consts::TAU * frequency * i as f64 / RATE).sin() * envelope * 0.025
                })
                .sum::<f64>() as f32
        })
        .collect();
    let mut centroids = Vec::new();
    for value in [0.25, 0.75] {
        let mut parameters = Parameters::default();
        parameters.set(9, value).unwrap();
        let mut processor = Processor::new(RATE).unwrap();
        let mut left = voice.clone();
        let mut right = voice.clone();
        processor
            .process(&mut left, &mut right, parameters)
            .unwrap();
        let tail = &left[48000..];
        let mut weight = 0.;
        let mut total = 0.;
        for harmonic in 1..40 {
            let frequency = 100. * harmonic as f64;
            let energy = power(tail, frequency);
            weight += frequency * energy;
            total += energy;
        }
        assert!(total > 1.);
        centroids.push(weight / total);
    }
    assert!(
        centroids[1] > centroids[0] * 1.3,
        "formant envelope does not move: {centroids:?}"
    );
}

#[test]
#[ignore = "Requires the local preset fixtures"]
fn all_measured_factory_archives_restore_the_checked_values() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("reference/presets");
    let mut count = 0;
    for entry in std::fs::read_dir(root).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().is_none_or(|x| x != "toy") {
            continue;
        }
        let data = std::fs::read(&path).unwrap();
        let (name, values) = little_alter_boy::preset::import_factory(&data).unwrap();
        let measured = little_alter_boy::factory_presets::FACTORY_PRESETS
            .iter()
            .find(|p| p.name == name)
            .unwrap();
        for (i, id) in (7..=13).enumerate() {
            assert_eq!(values.get(id).unwrap(), measured.values[i]);
        }
        count += 1;
    }
    assert_eq!(count, 12);
}
