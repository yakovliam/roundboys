use decapitator::{PARAMETERS, Parameters, Processor};
#[test]
fn parameters_and_state_match_observed_ranges() {
    let mut p = Parameters::default();
    assert_eq!(PARAMETERS.len(), 12);
    p.set(10, 4.).unwrap();
    assert!(p.set(10, 4.01).is_err());
    assert!(p.set(11, 1.01).is_err());
    assert!(p.set(11, f32::NAN).is_err());
    assert!(p.set(999, 0.).is_err());
    assert_eq!(Parameters::decode(&p.encode()).unwrap(), p);
    let mut data = p.encode();
    data[8..12].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Parameters::decode(&data).is_err());
    assert!(Parameters::decode(&data[..55]).is_err());
}
#[test]
fn all_styles_are_finite_distinct_and_block_independent() {
    let input: Vec<f32> = (0..12000).map(|i| (i as f32 * 0.1).sin() * 0.3).collect();
    let mut outcomes = Vec::new();
    for style in 0..5 {
        let mut p = Parameters::default();
        p.set(10, style as f32).unwrap();
        p.set(11, 1.).unwrap();
        p.set(12, 1.).unwrap();
        let mut a = Processor::new(48000.).unwrap();
        let mut b = Processor::new(48000.).unwrap();
        let (mut l, mut r) = (input.clone(), input.clone());
        let (mut sl, mut sr) = (input.clone(), input.clone());
        a.process(&mut l, &mut r, p).unwrap();
        for (l, r) in sl.chunks_mut(63).zip(sr.chunks_mut(63)) {
            b.process(l, r, p).unwrap();
        }
        assert_eq!(l, sl);
        assert_eq!(r, sr);
        assert!(l.iter().all(|v| v.is_finite() && v.abs() < 10.));
        outcomes.push(l[10000].to_bits());
    }
    outcomes.sort();
    outcomes.dedup();
    assert_eq!(outcomes.len(), 5);
}
#[test]
fn dry_delay_reset_and_sample_rates() {
    for rate in [8000., 44100., 48000., 96000., 192000.] {
        let mut a = Processor::new(rate).unwrap();
        let mut p = Parameters::default();
        p.set(7, 1.).unwrap();
        let mut zeros = vec![0.; rate as usize];
        let mut right = zeros.clone();
        a.process(&mut zeros, &mut right, p).unwrap();
        let mut l = [0.; 128];
        let mut r = [0.; 128];
        l[0] = 0.1;
        r[0] = -0.1;
        a.process(&mut l, &mut r, p).unwrap();
        assert_eq!(l[62], 0.1);
        assert_eq!(r[62], -0.1);
        assert!(l.iter().enumerate().all(|(i, v)| i == 62 || *v == 0.));
        a.reset();
        let mut l = [0.; 128];
        let mut r = [0.; 128];
        a.process(&mut l, &mut r, Parameters::default()).unwrap();
        assert!(l.iter().all(|v| *v == 0.));
    }
    assert!(Processor::new(f64::NAN).is_err());
}
#[test]
fn unknown_presets_leave_ffi_values_unchanged() {
    let bytes=b"WIDGET = Decapitator;\rVERSION = 4;\rSAVED_BY_VERSION = 5.3.2;\rBUILDNUM = 15253;\rARCHIVE =unknown;\r";
    let mut out = [0.123; 12];
    let mut error = [0i8; 256];
    assert_ne!(
        unsafe {
            decapitator::dc_decode_preset(
                bytes.as_ptr(),
                bytes.len(),
                out.as_mut_ptr(),
                error.as_mut_ptr(),
                error.len(),
            )
        },
        0
    );
    assert_eq!(out, [0.123; 12]);
    assert!(decapitator::preset::import_factory(&vec![0; 1024 * 1024 + 1]).is_err());
}
#[test]
#[ignore = "Requires local original presets"]
fn local_factory_headers_and_archives() {
    fn visit(path: &std::path::Path, count: &mut usize) {
        for f in std::fs::read_dir(path).unwrap() {
            let p = f.unwrap().path();
            if p.is_dir() {
                visit(&p, count);
            } else if p.extension().and_then(|x| x.to_str()) == Some("toy") {
                let bytes = std::fs::read(&p).unwrap();
                let parsed = decapitator::preset::ToyPreset::parse(&bytes).unwrap();
                assert_eq!(parsed.original_bytes(), bytes);
                let (_, values) = decapitator::preset::import_factory(&bytes).unwrap();
                for param in PARAMETERS {
                    assert!((0.0..=param.maximum).contains(&values.get(param.id).unwrap()));
                }
                *count += 1;
            }
        }
    }
    let mut count = 0;
    visit(
        &std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("reference/presets"),
        &mut count,
    );
    assert_eq!(count, 47);
}

#[test]
fn meter_tracks_output_level_without_drive_overload() {
    for rate in [44100., 48000., 96000.] {
        let mut processor = Processor::new(rate).unwrap();
        assert_eq!(processor.meter_db(), -60.);
        let mut parameters = Parameters::default();
        // Dry mode isolates the meter calibration from the provisional distortion model.
        parameters.set(16, 0.).unwrap();
        let mut previous = -60.;
        for (amplitude, expected) in [(0.1, -17.01), (0.25, -9.05), (0.5, -3.03), (0.8, 1.05)] {
            let mut left: Vec<f32> = (0..rate as usize * 2)
                .map(|i| (std::f32::consts::TAU * 440. * i as f32 / rate as f32).sin() * amplitude)
                .collect();
            let mut right = left.clone();
            processor
                .process(&mut left, &mut right, parameters)
                .unwrap();
            let reading = processor.meter_db();
            assert!(
                (reading - expected).abs() < 0.1,
                "{rate}: {reading} vs {expected}"
            );
            assert!(reading > previous);
            previous = reading;
        }
        parameters.set(16, 1.).unwrap();
        parameters.set(11, 0.8).unwrap();
        let mut left: Vec<f32> = (0..rate as usize * 2)
            .map(|i| (std::f32::consts::TAU * 440. * i as f32 / rate as f32).sin() * 0.1)
            .collect();
        let mut right = left.clone();
        processor
            .process(&mut left, &mut right, parameters)
            .unwrap();
        assert!(
            processor.meter_db() < 0.,
            "normal driven audio must not pin the meter"
        );
        let mut silence = vec![0.; rate as usize * 3];
        let mut right = silence.clone();
        processor
            .process(&mut silence, &mut right, parameters)
            .unwrap();
        assert_eq!(processor.meter_db(), -60.);
        processor.reset();
        assert_eq!(processor.meter_db(), -60.);
    }
}
