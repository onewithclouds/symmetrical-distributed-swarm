// native/swarm_native/src/nifs/legacy.rs

use rustler::ResourceArc;
use std::sync::atomic::Ordering;
use crate::state::arena::{SwarmState, FRAME_WIDTH, FRAME_HEIGHT};
use crate::vision::detector; // Import the Logic

#[rustler::nif]
pub fn update_spatial_state(state: ResourceArc<SwarmState>, x: i32, y: i32, status: u32) -> String {
    state.spatial_memory.insert((x, y), status);
    "ok".to_string()
}

#[rustler::nif]
pub fn get_spatial_state(state: ResourceArc<SwarmState>, x: i32, y: i32) -> u32 {
    match state.spatial_memory.get(&(x, y)) {
        Some(val) => *val,
        None => 0,
    }
}

/// The "Wake-on-Motion" Trigger.
///
/// Tactic: Triple Buffer Roulette.
/// We compare the 'Ready' slot (Current) against the 'Idle' slot (Reference).
/// This allows us to detect change without allocating a dedicated background buffer.
#[rustler::nif]
pub fn detect_change(state: ResourceArc<SwarmState>) -> (u32, u32, u32, u32) {
    let memory = &state.memory;

    // 1. Identify the Slots
    // We load Acquire to ensure we see the latest updates from the camera thread.
    let ready_idx = memory.ready_idx.load(Ordering::Acquire);
    let write_idx = memory.write_idx.load(Ordering::Acquire);

    // Find the "Cold" slot. It's the one that is neither Ready nor Writing.
    // In a 3-slot system, there is always exactly one such slot.
    let ref_idx = (0..3)
        .find(|&i| i != ready_idx && i != write_idx)
        .unwrap_or((ready_idx + 1) % 3); // Fallback (should never happen)

    // 2. Lock and Load
    // We lock the slots to prevent data tearing, though contention is low.
    let current_slot = &memory.slots[ready_idx];
    let ref_slot = &memory.slots[ref_idx];

    // Lock scopes
    let current_guard = current_slot.data.lock().unwrap();
    let ref_guard = ref_slot.data.lock().unwrap();

    // 3. Execute the Vision Logic (Stateless)
    // Step 10 = Scan every 10th pixel (High speed, lower accuracy)
    let result = detector::calculate_motion_bbox(
        &current_guard,
        &ref_guard,
        FRAME_WIDTH,
        FRAME_HEIGHT,
        10 
    );

    // 4. Return to Elixir
    match result {
        Some(roi) => (roi.x, roi.y, roi.w, roi.h),
        None => (0, 0, 0, 0),
    }
}