use rustler::{ResourceArc, Binary, Env, Term, Atom, Encoder};
use std::sync::RwLock;
use image::{GrayImage, ImageBuffer, Luma};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        no_change,
        change,
        invalid_shape
    }
}

struct RetinaState {
    // We use GrayImage (8-bit Luma) for maximum speed and compatibility
    last_frame: RwLock<Option<GrayImage>>,
    width: u32,
    height: u32,
    threshold: u32,
}

#[rustler::nif]
fn init_retina(width: u32, height: u32, threshold: u32) -> (Atom, ResourceArc<RetinaState>) {
    let state = RetinaState {
        last_frame: RwLock::new(None),
        width,
        height,
        threshold,
    };
    (atoms::ok(), ResourceArc::new(state))
}

#[rustler::nif]
fn detect_change<'a>(env: Env<'a>, resource: ResourceArc<RetinaState>, input: Binary<'a>) -> Term<'a> {
    let mut state = resource.last_frame.write().unwrap();
    
    // Safety: Ensure input binary matches expected dimensions
    if input.len() != (resource.width * resource.height) as usize {
        return (atoms::error(), atoms::invalid_shape()).encode(env);
    }

    // 1. Ingest: Zero-copy creation of the container (vectors own data)
    let current_bytes = input.as_slice().to_vec();
    let current_img = match GrayImage::from_raw(resource.width, resource.height, current_bytes) {
        Some(img) => img,
        None => return (atoms::error(), atoms::invalid_shape()).encode(env),
    };

    match &*state {
        Some(previous_img) => {
            // 2. Fast Entropy Calculation (SAD)
            // We iterate manually for SIMD-friendly linear scanning
            let sad: u32 = current_img.as_raw().iter()
                .zip(previous_img.as_raw().iter())
                .map(|(a, b)| (*a as i32 - *b as i32).abs() as u32)
                .sum();

            if sad < resource.threshold {
                *state = Some(current_img);
                atoms::no_change().encode(env)
            } else {
                // 3. ROI Calculation
                // Note: In the future, we can use imageproc::contours here!
                let (x, y, w, h) = calculate_roi(&current_img, previous_img);
                *state = Some(current_img);
                (atoms::change(), (x, y, w, h)).encode(env)
            }
        }
        None => {
            *state = Some(current_img);
            atoms::no_change().encode(env)
        }
    }
}

// Tactical ROI Scanner
fn calculate_roi(current: &GrayImage, previous: &GrayImage) -> (u32, u32, u32, u32) {
    let width = current.width();
    let height = current.height();
    let mut min_x = width;
    let mut max_x = 0;
    let mut min_y = height;
    let mut max_y = 0;
    
    let noise_gate = 15; 

    // Linear scan is cache-friendly
    for (i, (p1, p2)) in current.as_raw().iter().zip(previous.as_raw().iter()).enumerate() {
        let diff = (*p1 as i32 - *p2 as i32).abs();
        
        if diff > noise_gate {
            let x = (i as u32) % width;
            let y = (i as u32) / width;

            if x < min_x { min_x = x; }
            if x > max_x { max_x = x; }
            if y < min_y { min_y = y; }
            if y > max_y { max_y = y; }
        }
    }

    if max_x < min_x {
        return (0, 0, width, height);
    }

    (min_x, min_y, max_x - min_x, max_y - min_y)
}

rustler::init!("Elixir.SwarmBrain.Vision.Native", [init_retina, detect_change], load = on_load);

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(RetinaState, env);
    true
}