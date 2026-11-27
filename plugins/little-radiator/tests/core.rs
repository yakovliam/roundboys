use little_radiator::{Parameters, Processor, preset::ToyPreset};
#[test]
fn state_round_trip_and_invalid_data() {
    let mut p = Parameters::default();
    p.set(8, 0.123).unwrap();
    p.set(10, 1.).unwrap();
    assert_eq!(Parameters::decode(&p.encode()).unwrap(), p);
    let before = p;
    assert!(p.set(99, 0.).is_err());
    assert!(p.set(8, f32::NAN).is_err());
    assert_eq!(p, before);
    let mut bytes = p.encode();
    bytes[8..12].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Parameters::decode(&bytes).is_err());
    assert!(Parameters::decode(&bytes[..27]).is_err());
}
#[test]
fn block_boundaries_do_not_change_audio() {
    let input: Vec<f32> = (0..5000).map(|i| (i as f32 * 0.125).sin() * 0.1).collect();
    let mut whole = input.clone();
    let mut whole_r = input.clone();
    let mut split = input.clone();
    let mut split_r = input;
    let mut a = Processor::new(48000.).unwrap();
    let mut b = Processor::new(48000.).unwrap();
    a.process(&mut whole, &mut whole_r, Parameters::default())
        .unwrap();
    for (l, r) in split.chunks_mut(63).zip(split_r.chunks_mut(63)) {
        b.process(l, r, Parameters::default()).unwrap();
    }
    assert_eq!(whole, split);
    assert_eq!(whole_r, split_r);
    a.reset();
    let mut zeros = vec![0.; 100];
    let mut right = zeros.clone();
    a.process(&mut zeros, &mut right, Parameters::default())
        .unwrap();
    assert!(zeros.iter().all(|x| x.is_finite()));
}
#[test]
fn settled_dry_path_has_48_frame_delay() {
    let mut p = Parameters::default();
    p.set(9, 0.).unwrap();
    let mut a = Processor::new(48000.).unwrap();
    // Settle our provisional smoother before testing the transport delay.
    let mut left = vec![0.; 192000];
    let mut right = left.clone();
    a.process(&mut left, &mut right, p).unwrap();
    let mut left = [0.; 128];
    let mut right = [0.; 128];
    left[0] = 0.1;
    right[0] = -0.2;
    a.process(&mut left, &mut right, p).unwrap();
    assert_eq!(left[48], 0.1);
    assert_eq!(right[48], -0.2);
    for (i, v) in left.iter().enumerate() {
        if i != 48 {
            assert!(v.abs() < 1e-30);
        }
    }
}
#[test]
fn presets_preserve_archive_without_claiming_to_decode_it() {
    let text=b"WIDGET = Little Radiator;\nVERSION = 4;\nSAVED_BY_VERSION = 4.1.6b2;\nARCHIVE =0101abc;;;;\n";
    for ending in ["\r", "\n", "\r\n"] {
        let text = std::str::from_utf8(text).unwrap().replace("\n", ending);
        assert!(ToyPreset::parse(text.as_bytes()).is_ok());
    }
    let p = ToyPreset::parse(text).unwrap();
    assert_eq!(p.original_bytes(), text);
    assert_eq!(p.archive, "0101abc;;;");
    let mut with_trailer = text.to_vec();
    with_trailer.extend_from_slice(&[0, 255, 128]);
    let p = ToyPreset::parse(&with_trailer).unwrap();
    assert_eq!(p.trailing_data, &[0, 255, 128]);
    assert_eq!(p.original_bytes(), with_trailer);
    assert!(ToyPreset::parse(b"WIDGET = Other;\n").is_err());
}
#[test]
fn extreme_controls_are_finite_at_supported_rates() {
    for rate in [8000., 44100., 48000., 96000., 192000.] {
        let mut a = Processor::new(rate).unwrap();
        let mut p = Parameters::default();
        p.set(8, 1.).unwrap();
        p.set(10, 1.).unwrap();
        let mut l = vec![1.; 10000];
        let mut r = vec![-1.; 10000];
        a.process(&mut l, &mut r, p).unwrap();
        assert!(l.iter().chain(&r).all(|v| v.is_finite() && v.abs() < 4.));
    }
    assert!(Processor::new(f64::NAN).is_err());
}

#[test]
fn unknown_archive_does_not_change_ffi_output() {
    let bytes =
        b"WIDGET = Little Radiator;\rVERSION = 4;\rSAVED_BY_VERSION = 5.0;\rARCHIVE =unknown;\r";
    let mut values = [0.123; 5];
    let mut message = [0i8; 200];
    let result = unsafe {
        little_radiator::lr_decode_preset(
            bytes.as_ptr(),
            bytes.len(),
            values.as_mut_ptr(),
            message.as_mut_ptr(),
            message.len(),
        )
    };
    assert_ne!(result, 0);
    assert_eq!(values, [0.123; 5]);
    let error = unsafe { std::ffi::CStr::from_ptr(message.as_ptr()) }
        .to_str()
        .unwrap();
    assert!(error.contains("14 checked"));
    assert_ne!(
        unsafe {
            little_radiator::lr_decode_preset(
                std::ptr::null(),
                0,
                values.as_mut_ptr(),
                std::ptr::null_mut(),
                0,
            )
        },
        0
    );
    let mut one = [123i8];
    assert_ne!(
        unsafe {
            little_radiator::lr_decode_preset(
                bytes.as_ptr(),
                bytes.len(),
                values.as_mut_ptr(),
                one.as_mut_ptr(),
                1,
            )
        },
        0
    );
    assert_eq!(one, [0]);
}
