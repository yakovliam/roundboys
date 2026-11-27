//! Independent Little AlterBoy development model. Sound matching remains open.
mod digest;
pub mod factory_presets;
pub mod parameters;
pub mod preset;
pub mod processor;
mod spectral;
pub use parameters::{PARAMETERS, Parameter, Parameters};
pub use processor::Processor;
#[unsafe(no_mangle)]
pub extern "C" fn la_create(rate: f64) -> *mut Processor {
    Processor::new(rate).map_or(std::ptr::null_mut(), |p| Box::into_raw(Box::new(p)))
}
/// # Safety
/// `ptr` must be null or a live pointer from la_create with exclusive access.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_destroy(ptr: *mut Processor) {
    if !ptr.is_null() {
        drop(unsafe { Box::from_raw(ptr) });
    }
}
/// # Safety
/// `ptr` must be live and exclusive. `values` must address 7 readable floats.
/// The two audio pointers must address `frames` writable floats without overlap.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_process(
    ptr: *mut Processor,
    left: *mut f32,
    right: *mut f32,
    frames: usize,
    values: *const f32,
) -> i32 {
    if ptr.is_null() || left.is_null() || right.is_null() || values.is_null() {
        return -1;
    }
    let mut p = Parameters::default();
    for (i, meta) in PARAMETERS.iter().enumerate() {
        if p.set(meta.id, unsafe { *values.add(i) }).is_err() {
            return -1;
        }
    }
    unsafe {
        (&mut *ptr).process(
            std::slice::from_raw_parts_mut(left, frames),
            std::slice::from_raw_parts_mut(right, frames),
            p,
        )
    }
    .map_or(-1, |_| 0)
}
/// # Safety
/// `ptr` must be live and exclusive.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_reset(ptr: *mut Processor) {
    if let Some(p) = unsafe { ptr.as_mut() } {
        p.reset();
    }
}

/// Import a checked factory archive. Output order matches PARAMETERS.
/// # Safety
/// `bytes` must address `length` readable bytes. `out_values` must address seven
/// writable floats. `message` must be null or address `capacity` writable bytes.
/// These regions must not overlap. Output values remain unchanged on failure.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_decode_preset(
    bytes: *const u8,
    length: usize,
    out_values: *mut f32,
    message: *mut std::ffi::c_char,
    capacity: usize,
) -> i32 {
    let result = if bytes.is_null() || out_values.is_null() {
        Err("Invalid preset buffer")
    } else if length > 1024 * 1024 {
        Err("The preset exceeds the 1 MiB limit")
    } else {
        crate::preset::import_factory(unsafe { std::slice::from_raw_parts(bytes, length) })
    };
    let error = match result {
        Ok((_, values)) => {
            for (i, id) in [7, 8, 9, 10, 11, 12, 13].into_iter().enumerate() {
                unsafe { out_values.add(i).write(values.get(id).unwrap()) };
            }
            if !message.is_null() && capacity > 0 {
                unsafe { message.write(0) };
            }
            return 0;
        }
        Err(error) => error,
    };
    if !message.is_null() && capacity > 0 {
        let count = error.len().min(capacity - 1);
        unsafe {
            std::ptr::copy_nonoverlapping(error.as_ptr(), message.cast(), count);
            message.add(count).write(0)
        };
    }
    -1
}

#[unsafe(no_mangle)]
pub extern "C" fn la_factory_preset_count() -> usize {
    factory_presets::FACTORY_PRESETS.len()
}
/// # Safety
/// `values` must address 7 writable floats. `name` must address `capacity`
/// writable bytes. The two output regions must not overlap.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_factory_preset(
    index: usize,
    values: *mut f32,
    name: *mut std::ffi::c_char,
    capacity: usize,
) -> i32 {
    let Some(preset) = factory_presets::FACTORY_PRESETS.get(index) else {
        return -1;
    };
    if values.is_null() || name.is_null() || capacity <= preset.name.len() {
        return -1;
    }
    unsafe {
        std::ptr::copy_nonoverlapping(preset.values.as_ptr(), values, 7);
        std::ptr::copy_nonoverlapping(preset.name.as_ptr(), name.cast(), preset.name.len());
        name.add(preset.name.len()).write(0);
    }
    0
}

/// # Safety
/// `ptr` must be a live processor with exclusive render-thread access.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn la_midi_event(
    ptr: *mut Processor,
    status: u32,
    note: u32,
    velocity: u32,
    offset: u32,
) -> i32 {
    if status > 255 || note > 127 || velocity > 127 {
        return -1;
    }
    unsafe { ptr.as_mut() }.map_or(-1, |p| {
        p.midi(status as u8, note as u8, velocity as u8, offset as usize)
            .map_or(-1, |_| 0)
    })
}
