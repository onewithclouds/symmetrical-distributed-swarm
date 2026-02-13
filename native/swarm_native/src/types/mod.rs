// native/swarm_native/src/types/mod.rs

pub mod atomic_f32;

// Re-export the primitive for easier access
pub use atomic_f32::AtomicF32;

/// The Physiological State of the Drone.
///
/// This struct aggregates the atomic telemetry.
/// Because each `AtomicF32` is aligned to 64 bytes (cache line isolation),
/// this struct guarantees no "False Sharing" between the Camera Thread (Writer)
/// and the NIF Thread (Reader).
pub struct Kinematics {
    pub vx: AtomicF32, // Velocity X
    pub vy: AtomicF32, // Velocity Y
    pub px: AtomicF32, // Position X (Integrated)
    pub py: AtomicF32, // Position Y (Integrated)
}

// Zero-initialization for boot
impl Default for Kinematics {
    fn default() -> Self {
        Self {
            vx: AtomicF32::new(0.0),
            vy: AtomicF32::new(0.0),
            px: AtomicF32::new(0.0),
            py: AtomicF32::new(0.0),
        }
    }
}