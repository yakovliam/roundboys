use std::{error::Error, fs::File, io::Read};
fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(2);
    }
}
fn run() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args_os().skip(1);
    let path = args.next().ok_or("Usage: import-preset path.toy")?;
    if args.next().is_some() {
        return Err("Usage: import-preset path.toy".into());
    }
    let mut bytes = Vec::new();
    File::open(path)?
        .take(1024 * 1024 + 1)
        .read_to_end(&mut bytes)?;
    let (name, values) = decapitator::preset::import_factory(&bytes)?;
    print!("{{\"preset\":\"{name}\",\"parameters\":{{");
    for (i, p) in decapitator::PARAMETERS.iter().enumerate() {
        if i > 0 {
            print!(",");
        }
        print!("\"{}\":{}", p.id, values.get(p.id).unwrap());
    }
    println!("}}}}");
    Ok(())
}
