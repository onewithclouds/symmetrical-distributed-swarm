// native/swarm_native/src/types/atomic_f32.rs

use std::sync::atomic::{AtomicU32, Ordering};

/// A floating-point number that can be safely shared between threads.
///
/// # ARCHITECTURAL TACTIC: Cache Isolation
/// We use `#[repr(align(64))]` to ensure that this value occupies its own
/// exclusive cache line. This prevents "False Sharing" where a write to 'vx'
/// invalidates the CPU cache for 'vy' just because they are neighbors.
///
/// Size penalty: Each float takes 64 bytes instead of 4.
/// Benefit: Zero bus contention between Camera (Write) and Elixir (Read).
#[repr(align(64))]
pub struct AtomicF32 {
    storage: AtomicU32,
}

impl AtomicF32 {
    /// Create a new atomic float.
    pub fn new(val: f32) -> Self {
        let bit_cast = val.to_bits();
        Self {
            storage: AtomicU32::new(bit_cast),
        }
    }

    /// Load the value (Elixir Reading).
    /// Ordering::Acquire ensures we see the latest write from the camera loop.
    #[inline(always)]
    pub fn load(&self) -> f32 {
        let bit_cast = self.storage.load(Ordering::Acquire);
        f32::from_bits(bit_cast)
    }

    /// Store a value (Camera Writing).
    /// Ordering::Release ensures that all math prior to this store is visible
    /// to the reader.
    #[inline(always)]
    pub fn store(&self, val: f32) {
        let bit_cast = val.to_bits();
        self.storage.store(bit_cast, Ordering::Release);
    }
}

// Allow default initialization (0.0)
impl Default for AtomicF32 {
    fn default() -> Self {
        Self::new(0.0)
    }
}