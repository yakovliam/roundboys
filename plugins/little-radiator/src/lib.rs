//! Independent development model. The wet path is provisional, not a sound match.
mod digest;
pub mod factory_presets;
pub mod parameters;
pub mod preset;
pub mod processor;
pub use parameters::{Parameter, Parameters};
pub use processor::Processor;

/// # Safety
/// The caller must release the returned pointer once with `lr_destroy`.
#[unsafe(no_mangle)]
pub extern "C" fn lr_create(rate: f64) -> *mut Processor {
    Processor::new(rate).map_or(std::ptr::null_mut(), |p| Box::into_raw(Box::new(p)))
}
/// # Safety
/// `ptr` must be null or a live pointer from `lr_create`, with exclusive access.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lr_destroy(ptr: *mut Processor) {
    if !ptr.is_null() {
        drop(unsafe { Box::from_raw(ptr) });
    }
}
/// # Safety
/// `ptr` must be live and exclusive. All audio pointers must address `frames`
/// floats. Left and right storage must not overlap. Processing occurs in place.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lr_process(
    ptr: *mut Processor,
    left: *mut f32,
    right: *mut f32,
    frames: usize,
    heat: f32,
    mix: f32,
    noise: f32,
    bias: f32,
    bypass: f32,
) -> i32 {
    if ptr.is_null() || left.is_null() || right.is_null() {
        return -1;
    }
    let mut p = Parameters::default();
    for (id, value) in [(8, heat), (9, mix), (12, noise), (10, bias), (7, bypass)] {
        if p.set(id, value).is_err() {
            return -1;
        }
    }
    let processor = unsafe { &mut *ptr };
    let left = unsafe { std::slice::from_raw_parts_mut(left, frames) };
    let right = unsafe { std::slice::from_raw_parts_mut(right, frames) };
    processor.process(left, right, p).map_or(-1, |_| 0)
}
/// # Safety
/// `ptr` must be a live pointer with exclusive access.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lr_reset(ptr: *mut Processor) {
    if let Some(p) = unsafe { ptr.as_mut() } {
        p.reset();
    }
}

/// Import a checked factory archive. Output order: Bypass, Heat, Mix, Bias, Noise.
/// # Safety
/// `bytes` must address `length` readable bytes. `out_values` must address five
/// writable floats. `message` must be null or address `capacity` writable bytes.
/// These regions must not overlap. Output values remain unchanged on failure.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lr_decode_preset(
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
            for (i, id) in [7, 8, 9, 10, 12].into_iter().enumerate() {
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
