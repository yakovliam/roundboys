use little_radiator::preset::ToyPreset;
#[test]
#[ignore = "Requires the local reference files"]
fn all_local_preset_headers_parse_and_preserve_bytes() {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("reference/presets");
    let mut count = 0;
    for file in std::fs::read_dir(path).unwrap() {
        let path = file.unwrap().path();
        if path.extension().and_then(|e| e.to_str()) != Some("toy") {
            continue;
        }
        let bytes = std::fs::read(&path).unwrap();
        let preset = ToyPreset::parse(&bytes).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
        assert_eq!(preset.original_bytes(), bytes);
        count += 1;
    }
    assert_eq!(count, 14);
}

#[test]
#[ignore = "Requires the local reference files"]
fn factory_import_uses_archive_identity_and_rejects_changes() {
    use little_radiator::preset::import_factory;
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("reference/presets");
    let bytes = std::fs::read(root.join("Bass Beef.toy")).unwrap();
    let (name, values) = import_factory(&bytes).unwrap();
    assert_eq!(name, "Bass Beef");
    assert_eq!(values.get(8), Some(0.74));
    assert_eq!(values.get(9), Some(0.5));
    assert_eq!(values.get(10), Some(1.));
    let text = std::str::from_utf8(&bytes)
        .unwrap()
        .replace('\r', "\r\n")
        .replace("4.1.6b2", "5.5.5");
    assert_eq!(import_factory(text.as_bytes()).unwrap().1, values);
    let mut changed = bytes.clone();
    let pos = changed.windows(7).position(|w| w == b"ARCHIVE").unwrap() + 12;
    changed[pos] = if changed[pos] == b'0' { b'1' } else { b'0' };
    assert!(import_factory(&changed).is_err());
    let changed = std::str::from_utf8(&bytes)
        .unwrap()
        .replace("Little Radiator", "Other");
    assert!(import_factory(changed.as_bytes()).is_err());
    assert!(import_factory(&vec![0; 1024 * 1024 + 1]).is_err());
    let mut decoded = [-1.; 5];
    let mut message = [1i8; 128];
    assert_eq!(
        unsafe {
            little_radiator::lr_decode_preset(
                bytes.as_ptr(),
                bytes.len(),
                decoded.as_mut_ptr(),
                message.as_mut_ptr(),
                128,
            )
        },
        0
    );
    assert_eq!(decoded, [0., 0.74, 0.5, 1., 1.]);
    assert_eq!(message[0], 0);
}
