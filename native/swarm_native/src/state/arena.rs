// native/swarm_native/src/state/arena.rs

use std::sync::{Arc, Mutex, RwLock};
use std::sync::atomic::{AtomicU32, AtomicUsize};
use std::process::Child;
use dashmap::DashMap; // <--- Critical for legacy support
use crate::types::Kinematics;

// Constants for Pre-Allocation
pub const FRAME_WIDTH: usize = 640;
pub const FRAME_HEIGHT: usize = 480;
pub const FRAME_CHANNELS: usize = 3;
pub const FRAME_SIZE: usize = FRAME_WIDTH * FRAME_HEIGHT * FRAME_CHANNELS;

/// The Raw Frame container.
pub struct FrameBuffer {
    pub data: Mutex<Vec<u8>>,
}

/// The Triple Buffer state machine.
/// Note: 'last_flow_grid' is REMOVED here because it is now thread-local in camera.rs
pub struct TripleBufferState {
    pub slots: [Arc<FrameBuffer>; 3],
    pub write_idx: AtomicUsize, 
    pub ready_idx: AtomicUsize,
}

/// The Swarm Resource (The "God Object" handle).
#[derive(Clone)] // 1. Allow cloning the handle
pub struct SwarmState {
    // 1. The Nervous System (400Hz Path)
    pub physiology: Arc<Kinematics>,        
    
    // 2. The Visual Cortex (30Hz Path)
    pub memory: Arc<TripleBufferState>,     
    
    // 3. The Health Monitor (Process Path)
    pub child_process: Arc<Mutex<Option<Child>>>,
    
    // 4. The Kill Switch (Control Path)
    pub running: Arc<AtomicU32>,            
    
    // 5. The Insect Eye (Math Path - Optical Flow Grid)
    pub flow_grid: Arc<RwLock<[f32; 200]>>, 

    // 6. The Spatial Memory (Legacy/Spatial Path)
    // Kept here so NIFs can access it via the main resource handle.
    pub spatial_memory: Arc<DashMap<(i32, i32), u32>>, 
}

impl SwarmState {
    pub fn new() -> Self {
        let buffer = Arc::new(TripleBufferState {
            slots: [
                Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; FRAME_SIZE]) }),
                Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; FRAME_SIZE]) }),
                Arc::new(FrameBuffer { data: Mutex::new(vec![0u8; FRAME_SIZE]) }),
            ],
            write_idx: AtomicUsize::new(0),
            ready_idx: AtomicUsize::new(2),
        });

        Self {
            physiology: Arc::new(Kinematics::default()),
            memory: buffer,
            child_process: Arc::new(Mutex::new(None)),
            running: Arc::new(AtomicU32::new(1)),
            flow_grid: Arc::new(RwLock::new([0.0; 200])),
            spatial_memory: Arc::new(DashMap::new()), // Initialize the storage
        }
    }
}

impl std::panic::RefUnwindSafe for SwarmState {}