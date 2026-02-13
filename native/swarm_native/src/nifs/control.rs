// native/swarm_native/src/nifs/control.rs

use rustler::ResourceArc;
use crate::state::arena::SwarmState;
use crate::vision::camera;
use rustler::Atom; // Add Atom to imports

/// The Watchdog Probe.
/// Checks if the FFmpeg child process is still running.
/// Returns :ok if alive, :error if dead or missing.
#[rustler::nif]
pub fn check_health(state: ResourceArc<SwarmState>) -> Atom {
    // Lock the child process mutex
    let mut lock = state.child_process.lock().unwrap();
    
    match *lock {
        Some(ref mut child) => {
            // try_wait() is non-blocking. 
            // It returns Ok(Some(status)) if the process has exited.
            // It returns Ok(None) if the process is still running.
            match child.try_wait() {
                Ok(None) => rustler::types::atom::ok(),       // Alive
                Ok(Some(_)) => rustler::types::atom::error(), // Dead (Exited)
                Err(_) => rustler::types::atom::error(),      // Error checking
            }
        },
        None => rustler::types::atom::error(), // No camera started
    }
}

/// Tactic 1: The Anchor
/// Allocates the entire memory arena (Triple Buffer + Flow Grid) upfront.
#[rustler::nif]
pub fn init_state() -> ResourceArc<SwarmState> {
    ResourceArc::new(SwarmState::new())
}

/// Tactic 4: The Heartbeat
/// Spawns the dedicated OS thread for FFmpeg.

#[rustler::nif]
pub fn start_camera(state: ResourceArc<SwarmState>, width: u32, height: u32) -> Atom {    
    // FIX: Dereference the ResourceArc (*) to get to the SwarmState, 
    // then Clone it to get an owned struct.
    let state_owned = (*state).clone(); 
    
    camera::spawn_heartbeat(state_owned, width, height);
    rustler::types::atom::ok()
}