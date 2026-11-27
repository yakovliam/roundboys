//! Preserves original preset bytes. ARCHIVE and trailing data remain opaque.
#[derive(Debug)]
pub struct ToyPreset<'a> {
    pub widget: &'a str,
    pub version: u32,
    pub saved_by: &'a str,
    pub archive: &'a str,
    pub trailing_data: &'a [u8],
    bytes: &'a [u8],
}
fn field<'a>(input: &mut &'a [u8], key: &str) -> Result<&'a str, &'static str> {
    if input.is_empty() {
        return Err("Missing preset header");
    }
    let end = input
        .iter()
        .position(|&b| b == b'\r' || b == b'\n')
        .unwrap_or(input.len());
    let line = std::str::from_utf8(&input[..end]).map_err(|_| "Preset header is not UTF-8")?;
    let mut next = end;
    if next < input.len() {
        let cr = input[next] == b'\r';
        next += 1;
        if cr && input.get(next) == Some(&b'\n') {
            next += 1;
        }
    }
    *input = &input[next..];
    let (name, value) = line.split_once('=').ok_or("Invalid preset field")?;
    if name.trim() != key {
        return Err("Unexpected preset field");
    }
    value
        .trim()
        .strip_suffix(';')
        .ok_or("Missing field terminator")
}
impl<'a> ToyPreset<'a> {
    pub fn parse(bytes: &'a [u8]) -> Result<Self, &'static str> {
        let mut input = bytes;
        let widget = field(&mut input, "WIDGET")?.trim();
        if widget != "Little Radiator" {
            return Err("Preset belongs to another plug-in");
        }
        let version = field(&mut input, "VERSION")?
            .trim()
            .parse()
            .map_err(|_| "Invalid preset version")?;
        if version != 4 {
            return Err("Unsupported preset version");
        }
        let saved_by = field(&mut input, "SAVED_BY_VERSION")?.trim();
        let archive = field(&mut input, "ARCHIVE")?.trim();
        if archive.is_empty() {
            return Err("Empty preset archive");
        }
        Ok(Self {
            widget,
            version,
            saved_by,
            archive,
            trailing_data: input,
            bytes,
        })
    }
    pub fn original_bytes(&self) -> &'a [u8] {
        self.bytes
    }
}

/// Import exact archives whose control values have been measured in the original.
/// Unknown archives fail. This does not claim a general archive decoder.
pub fn import_factory(bytes: &[u8]) -> Result<(&'static str, crate::Parameters), &'static str> {
    if bytes.len() > 1024 * 1024 {
        return Err("The preset exceeds the 1 MiB limit");
    }
    let preset = ToyPreset::parse(bytes)?;
    let digest = crate::digest::hex(preset.archive.as_bytes());
    let entry=crate::factory_presets::FACTORY_PRESETS.iter().find(|p|p.archive_sha256==digest)
        .ok_or("This archive is not supported yet. Import supports the 14 checked Little Radiator factory presets. Custom archives still need decoding.")?;
    let mut values = crate::Parameters::default();
    for (id, value) in [7, 8, 9, 10, 12].into_iter().zip(entry.values) {
        values.set(id, value)?;
    }
    Ok((entry.name, values))
}
