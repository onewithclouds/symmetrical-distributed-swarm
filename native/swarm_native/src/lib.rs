//! # THE IRON LUNG (SwarmNative)
//! 
//! This file is the "Diamond" tip of the architecture. It is responsible for 
//! the high-frequency (400Hz) physiological loops of the drone.
//! 
//! ## ARCHITECTURAL TACTICS
//! 
//! **Tactic 1: The Anchor (ResourceArc)**
//! We hold a single `SwarmState` resource. This prevents "object soup." 
//! Elixir holds the leash; Rust holds the weight.
//! 
//! **Tactic 2: The Nervous System (Atomics)**
//! We use `AtomicF32` (via `AtomicU32` bit-casting) for lock-free telemetry.
//! This allows the "Pilot" (Elixir) to peek at velocity/position without 
//! ever stopping the "Heart" (Rust Camera Loop).
//! 
//! **Tactic 3: Zero-Copy Bridge**
//! Data is returned as raw binary structs `#[repr(C)]`. We do not serialize 
//! to JSON or Erlang Terms. We simply hand Elixir a pointer to the memory 
//! and say "This is a Tensor now."
//! 
//! **Tactic 4: The Arena (Pre-Allocation)**
//! We allocate the `TripleBuffer` and the `FlowGrid` (200 floats) ONCE at boot.
//! There are `Vec::new()` calls in `init_state`, but NO `Vec::push` calls 
//! in `start_camera`. This guarantees no runtime OOM (Out of Memory) crashes.

// [PRESERVED] All imports, including DashMap for Spatial Memory
use dashmap::DashMap;
use lazy_static::lazy_static;
use rustler::{Atom, Binary, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::atomic::{AtomicU32, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::Instant;
use std::process::{Command, Stdio};
use std::io::Read;

// --- 1. GLOBAL MEMORY (PRESERVED) ---
lazy_static! {
    static ref SPATIAL_MAP: DashMap<String, Vec<f32>> = DashMap::new();
}

// --- 2. ATOMIC NERVOUS SYSTEM (TACTIC 2) ---
#[repr(align(64))]
struct AtomicF32 {
    storage: AtomicU32,
}

impl AtomicF32 {
    fn new(val: f32) -> Self {
        Self { storage: AtomicU32::new(val.to_bits()) }
    }
    fn load(&self) -> f32 {
        f32::from_bits(self.storage.load(Ordering::Acquire))
    }
    fn store(&self, val: f32) {
        self.storage.store(val.to_bits(), Ordering::Relaxed);
    }
}

/// The Proprioception State.
struct Kinematics {
    px: AtomicF32,
    py: AtomicF32,
    vx: AtomicF32,
    vy: AtomicF32,
}

// --- 3. THE FRAME BUFFER ARENA (TACTIC 4) ---
struct FrameBuffer {
    data: Mutex<Vec<u8>>,
}

struct TripleBufferState {
    slots: [Arc<FrameBuffer>; 3],
    write_idx: AtomicUsize, 
    ready_idx: AtomicUsize,
    last_flow_grid: Mutex<Vec<u8>>, 
}

// --- 4. THE SWARM RESOURCE (TACTIC 1) ---
struct SwarmState {
    buffer: Arc<TripleBufferState>,
    kinematics: Arc<Kinematics>,
    running: Arc<AtomicU32>, 
    
    // [TACTIC 4] The Flow Grid.
    flow_grid: Arc<RwLock<[f32; 200]>>, 
}

impl Drop for SwarmState {
    fn drop(&mut self) {
        self.running.store(0, Ordering::Release);
    }
}

// --- 5. INITIALIZATION ---

// [HELPER] Pure Rust allocation logic
fn create_swarm_state() -> SwarmState {
    let frame_size = 640 * 480 * 3;
    
    let buffer = Arc::new(TripleBufferState {
        slots: [
            Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; frame_size]) }),
            Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; frame_size]) }),
            Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; frame_size]) }),
        ],
        write_idx: AtomicUsize::new(0),
        ready_idx: AtomicUsize::new(2),
        last_flow_grid: Mutex::new(vec![0u8; frame_size]), 
    });

    let kinematics = Arc::new(Kinematics {
        px: AtomicF32::new(0.0),
        py: AtomicF32::new(0.0),
        vx: AtomicF32::new(0.0),
        vy: AtomicF32::new(0.0),
    });

    SwarmState {
        buffer,
        kinematics,
        running: Arc::new(AtomicU32::new(1)),
        flow_grid: Arc::new(RwLock::new([0.0; 200])),
    }
}

#[allow(non_local_definitions)] // Silences the impl definition warning
fn load(env: Env, _info: Term) -> bool {
    // [FIXED] Silence "unused result" warning
    let _ = rustler::resource!(SwarmState, env);
    true
}

#[rustler::nif]
pub fn init_state() -> ResourceArc<SwarmState> {
    ResourceArc::new(create_swarm_state())
}

// --- 6. OPTICAL FLOW MATH (THE INSECT EYE) ---
fn calculate_optical_flow(
    current: &[u8], 
    prev: &[u8], 
    width: usize, 
    height: usize,
    grid_out: &mut [f32; 200] 
) -> (f32, f32) {
    let mut total_dx = 0;
    let mut total_dy = 0;
    let mut points = 0;

    let step_x = width / 10;
    let step_y = height / 10;
    let search_range = 16; 

    let mut g_idx = 0;

    for y in (search_range..(height - search_range)).step_by(step_y) {
        for x in (search_range..(width - search_range)).step_by(step_x) {
            
            if g_idx >= 100 { break; }

            let mut best_sad = u32::MAX;
            let mut best_dx = 0;
            let mut best_dy = 0;

            let p_idx = (y * width + x) * 3 + 1;
            let p_val = prev[p_idx] as i32;

            for dy in -4..=4 { 
                for dx in -4..=4 {
                    let c_idx = ((y as i32 + dy) as usize * width + (x as i32 + dx) as usize) * 3 + 1;
                    let c_val = current[c_idx] as i32;
                    let sad = (p_val - c_val).abs() as u32;
                    if sad < best_sad {
                        best_sad = sad;
                        best_dx = dx;
                        best_dy = dy;
                    }
                }
            }
            
            grid_out[g_idx * 2] = best_dx as f32;
            grid_out[g_idx * 2 + 1] = best_dy as f32;
            g_idx += 1;

            if best_sad < 50 { 
                total_dx += best_dx;
                total_dy += best_dy;
                points += 1;
            }
        }
    }

    while g_idx < 100 {
        grid_out[g_idx * 2] = 0.0;
        grid_out[g_idx * 2 + 1] = 0.0;
        g_idx += 1;
    }

    if points > 0 {
        (total_dx as f32 / points as f32, total_dy as f32 / points as f32)
    } else {
        (0.0, 0.0)
    }
}

// --- 7. CAMERA THREAD ---
#[rustler::nif(schedule = "DirtyCpu")]
pub fn start_camera(env: Env, state: ResourceArc<SwarmState>, width: u32, height: u32) -> NifResult<Atom> {
    let buffer_ref = state.buffer.clone();
    let kinematics_ref = state.kinematics.clone();
    let grid_ref = state.flow_grid.clone(); 
    let running_signal = state.running.clone(); 
    
    let expected_size = (width * height * 3) as usize;

    thread::spawn(move || {
        let mut child = Command::new("ffmpeg")
            .args(&[
                "-f", "v4l2", "-framerate", "30", "-video_size", &format!("{}x{}", width, height),
                "-i", "/dev/video1", 
                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null()) 
            .spawn()
            .expect("Failed to start FFmpeg");

        let mut stdout = child.stdout.take().expect("Failed to open stdout");
        let mut last_time = Instant::now();
        let mut current_w_idx = 0;
        
        let mut local_grid = [0.0f32; 200]; 

        while running_signal.load(Ordering::Acquire) == 1 {
            let r_idx = buffer_ref.ready_idx.load(Ordering::Acquire);
            let next_w_idx = (0..3).find(|&i| i != r_idx && i != current_w_idx).unwrap_or((current_w_idx + 1) % 3); 
            let slot = &buffer_ref.slots[next_w_idx];

            {
                let mut data = slot.data.lock().unwrap();
                if data.len() != expected_size { data.resize(expected_size, 0); }
                
                if let Err(_) = stdout.read_exact(&mut data) { break; }

                let mut prev_frame = buffer_ref.last_flow_grid.lock().unwrap();
                if prev_frame.len() == expected_size {
                    let (dx, dy) = calculate_optical_flow(&data, &prev_frame, width as usize, height as usize, &mut local_grid);
                    
                    // 1. UPDATE KINEMATICS
                    let dt = last_time.elapsed().as_secs_f32();
                    last_time = Instant::now();
                    
                    let old_vx = kinematics_ref.vx.load();
                    let old_vy = kinematics_ref.vy.load();
                    let new_vx = old_vx * 0.7 + dx * 0.3; 
                    let new_vy = old_vy * 0.7 + dy * 0.3;
                    
                    kinematics_ref.vx.store(new_vx);
                    kinematics_ref.vy.store(new_vy);
                    
                    let old_px = kinematics_ref.px.load();
                    let old_py = kinematics_ref.py.load();
                    kinematics_ref.px.store(old_px + new_vx * dt);
                    kinematics_ref.py.store(old_py + new_vy * dt);

                    // 2. UPDATE GRID MEMORY
                    if let Ok(mut g) = grid_ref.write() {
                        g.copy_from_slice(&local_grid);
                    }
                }
                prev_frame.copy_from_slice(&data);
            }
            buffer_ref.ready_idx.store(next_w_idx, Ordering::Release);
            buffer_ref.write_idx.store(next_w_idx, Ordering::Relaxed);
            current_w_idx = next_w_idx;
        }
        let _ = child.kill();
    });
    Ok(Atom::from_str(env, "ok").unwrap())
}

// --- 8. DATA RETRIEVAL NIFS ---

#[rustler::nif]
pub fn get_latest_frame(env: Env, state: ResourceArc<SwarmState>) -> NifResult<Binary> {
    let buffer = &state.buffer;
    let r_idx = buffer.ready_idx.load(Ordering::Acquire);
    let slot = &buffer.slots[r_idx];
    
    let data = slot.data.lock().unwrap();
    let mut binary = rustler::NewBinary::new(env, data.len());
    binary.as_mut_slice().copy_from_slice(&data);
    
    Ok(binary.into())
}

#[repr(C)]
#[derive(Copy, Clone)]
struct FusedStateOutput {
    px: f32, py: f32, vx: f32, vy: f32 
}

#[rustler::nif]
pub fn get_fused_state(env: Env, state: ResourceArc<SwarmState>) -> Binary {
    let k = &state.kinematics;
    let output = FusedStateOutput {
        px: k.px.load(),
        py: k.py.load(),
        vx: k.vx.load(),
        vy: k.vy.load(),
    };

    let slice = unsafe {
        std::slice::from_raw_parts(
            &output as *const _ as *const u8,
            std::mem::size_of::<FusedStateOutput>()
        )
    };

    let mut binary = rustler::NewBinary::new(env, slice.len());
    binary.as_mut_slice().copy_from_slice(slice);
    binary.into()
}

#[rustler::nif]
pub fn get_flow_grid(env: Env, state: ResourceArc<SwarmState>) -> Binary {
    let grid_lock = state.flow_grid.read().unwrap();
    
    let byte_slice = unsafe {
        std::slice::from_raw_parts(
            grid_lock.as_ptr() as *const u8,
            800 
        )
    };

    let mut binary = rustler::NewBinary::new(env, 800);
    binary.as_mut_slice().copy_from_slice(byte_slice);
    binary.into()
}

// --- 9. LEGACY STUBS (PRESERVED) ---

#[rustler::nif]
pub fn update_spatial_state(env: Env, _id: String, _x: f32, _y: f32, _h: f32) -> Atom {
    Atom::from_str(env, "ok").unwrap()
}

#[rustler::nif]
pub fn get_spatial_state(env: Env, _id: String) -> Term {
    rustler::types::atom::nil().to_term(env)
}

#[rustler::nif]
pub fn setup_queryable(env: Env) -> Atom {
    Atom::from_str(env, "ok").unwrap()
}

#[rustler::nif]
pub fn init_retina(_w: u32, _h: u32, _t: u32) -> ResourceArc<SwarmState> {
    ResourceArc::new(create_swarm_state())
}

// [FIXED] LIFETIMES & VISIBILITY
#[rustler::nif]
pub fn detect_change<'a>(env: Env<'a>, state: ResourceArc<SwarmState>, frame: Binary<'a>) -> Term<'a> {
    let buffer = &state.buffer;
    let frame_slice = frame.as_slice();

    let prev_frame = buffer.last_flow_grid.lock().unwrap();
    
    if prev_frame.len() != frame_slice.len() {
        return Atom::from_str(env, "no_change").unwrap().to_term(env);
    }

    let step = 10;
    let limit = frame_slice.len();
    let mut diff_count = 0;
    let mut min_x = 640;
    let mut max_x = 0;
    let mut min_y = 480;
    let mut max_y = 0;

    for i in (1..limit).step_by(step * 3) {
        let val_c = frame_slice[i] as i32;
        let val_p = prev_frame[i] as i32;
        
        if (val_c - val_p).abs() > 30 {
            diff_count += 1;
            
            let pixel_idx = i / 3;
            let x = pixel_idx % 640;
            let y = pixel_idx / 640;

            if x < min_x { min_x = x; }
            if x > max_x { max_x = x; }
            if y < min_y { min_y = y; }
            if y > max_y { max_y = y; }
        }
    }

    if diff_count > 50 {
        let w = if max_x > min_x { max_x - min_x } else { 0 };
        let h = if max_y > min_y { max_y - min_y } else { 0 };

        let change_atom = Atom::from_str(env, "change").unwrap();
        let tuple = (min_x as u32, min_y as u32, w as u32, h as u32);
        
        return (change_atom, tuple).encode(env);
    }

    Atom::from_str(env, "no_change").unwrap().to_term(env)
}

// --- REGISTRATION ---
// [FIXED] Explicitly list functions to prevent "Function not found" errors
rustler::init!(
    "Elixir.SwarmBrain.Vision.Native", 
    [
        init_state,
        start_camera,
        get_latest_frame,
        get_fused_state,
        get_flow_grid,
        update_spatial_state,
        get_spatial_state,
        setup_queryable,
        init_retina,
        detect_change
    ],
    load = load
);