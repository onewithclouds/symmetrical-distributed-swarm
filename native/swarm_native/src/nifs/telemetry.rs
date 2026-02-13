// native/swarm_native/src/nifs/telemetry.rs

use rustler::{Env, ResourceArc, Binary, OwnedBinary};
use std::sync::atomic::Ordering;
use crate::state::arena::{SwarmState, FRAME_SIZE};

/// Returns the Optical Flow grid (200 floats) as a raw binary.
/// Elixir Nx can cast this directly to a Tensor:
/// t = Nx.from_binary(bin, {:f, 32})
#[rustler::nif]
pub fn get_flow_grid(env: Env, state: ResourceArc<SwarmState>) -> Binary {
    let grid_lock = state.flow_grid.read().unwrap();
    
    // Create an owned binary of the correct size (200 floats * 4 bytes)
    let mut binary = OwnedBinary::new(200 * 4).unwrap();
    
    // Unsafe copy for speed (we know the sizes match perfectly)
    let src_ptr = grid_lock.as_ptr() as *const u8;
    let dst_ptr = binary.as_mut_slice().as_mut_ptr();
    
    unsafe {
        std::ptr::copy_nonoverlapping(src_ptr, dst_ptr, 200 * 4);
    }
    
    binary.release(env)
}

/// Returns the latest camera frame from the Triple Buffer.
/// Logic: Read 'ready_idx', lock that slot, copy to Binary.
#[rustler::nif]
pub fn get_latest_frame(env: Env, state: ResourceArc<SwarmState>) -> Binary {
    let ready_idx = state.memory.ready_idx.load(Ordering::Acquire);
    let slot = &state.memory.slots[ready_idx];
    
    let frame_guard = slot.data.lock().unwrap();
    
    // Copy the frame data into an Elixir Binary
    let mut binary = OwnedBinary::new(FRAME_SIZE).unwrap();
    binary.as_mut_slice().copy_from_slice(&frame_guard);
    
    binary.release(env)
}

/// Returns the Fused Kinematics (Vx, Vy, Px, Py)
#[rustler::nif]
pub fn get_fused_state(state: ResourceArc<SwarmState>) -> (f32, f32, f32, f32) {
    let phys = &state.physiology;
    (
        phys.vx.load(),
        phys.vy.load(),
        phys.px.load(),
        phys.py.load()
    )
}