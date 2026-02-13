// native/swarm_native/src/lib.rs

//! # THE IRON LUNG (SwarmNative) - Refactored
//! 
//! This is the "Diamond" tip of the architecture, now modularized 
//! for Class A performance and maintainability.

// 1. Module Registration
// These must match the folder names in src/
mod types;
mod state;
mod vision;
mod nifs;

use rustler::{Env, Term};

/// The 'on_load' handler. 
/// Registers the SwarmState resource so the BEAM can manage its lifecycle.
fn load(env: Env, _info: Term) -> bool {
    // Matches src/state/arena.rs
    rustler::resource!(state::arena::SwarmState, env);
    true
}

// THE FINAL MANIFEST
rustler::init!(
    "Elixir.SwarmBrain.Vision.Native",
    [
        // 1. Control Path (nifs/control.rs)
        nifs::control::init_state,
        nifs::control::start_camera,
        nifs::control::check_health,

        // 2. Telemetry Path (nifs/telemetry.rs)
        // CHANGED: 'sensing' -> 'telemetry' to match your file name
        nifs::telemetry::get_latest_frame,
        nifs::telemetry::get_fused_state,
        nifs::telemetry::get_flow_grid,

        // 3. Legacy Path (nifs/legacy.rs)
        // Note: Removed 'setup_queryable'/'init_retina' as they are not in legacy.rs
        nifs::legacy::detect_change,
        nifs::legacy::update_spatial_state,
        nifs::legacy::get_spatial_state
    ],
    load = load
);