// native/swarm_native/src/nifs/mod.rs

pub mod control;   // init_state, start_camera
pub mod telemetry; // get_fused_state, get_latest_frame
pub mod legacy;    // detect_change, update_spatial_state