// native/swarm_native/src/vision/detector.rs

/// THE WATCHDOG (Motion Detection)
///
/// This module implements a "Sparse Pixel Difference" algorithm.
/// Unlike the Optical Flow (which runs at 30Hz on the GPU/SIMD path),
/// this is a lightweight CPU scan intended for "Wake-on-Motion" or 
/// security triggers.
///
/// Refactored from the original 'detect_change' in lib.rs.

#[derive(Debug, Clone, Copy)]
pub struct MotionROI {
    pub x: u32,
    pub y: u32,
    pub w: u32,
    pub h: u32,
}

/// Scans two frame slices for pixel differences.
/// 
/// # Arguments
/// * `current` - The active frame buffer (RGB24).
/// * `reference` - The background or previous frame to compare against.
/// * `width` - Frame width (640).
/// * `height` - Frame height (480).
/// * `step` - Scan density (e.g., 10 = check every 10th pixel).
///
/// # Returns
/// * `Some(MotionROI)` if changes exceed the threshold.
/// * `None` if the scene is stable.
pub fn calculate_motion_bbox(
    current: &[u8], 
    reference: &[u8], 
    width: usize, 
    _height: usize, 
    step: usize
) -> Option<MotionROI> {
    
    // Safety check: Buffer sizes must match
    if current.len() != reference.len() {
        return None;
    }

    let mut diff_count = 0;
    
    // Bounding box accumulators (inverted init)
    let mut min_x = width;
    let mut max_x = 0;
    let mut min_y = usize::MAX; // temporary use usize for logic
    let mut max_y = 0;

    // We step by (step * 3) to jump pixels while respecting RGB stride
    let stride = step * 3;
    let limit = current.len();

    // The Scan Loop
    // We start at 0 (or 1 in original) and jump by 'stride'
    for i in (0..limit).step_by(stride) {
        // Fast path: Direct integer comparison
        let val_c = current[i] as i32;
        let val_ref = reference[i] as i32;

        // Threshold hardcoded to 30 (approx 12% brightness change)
        if (val_c - val_ref).abs() > 30 {
            diff_count += 1;

            let pixel_idx = i / 3;
            let x = pixel_idx % width;
            let y = pixel_idx / width;

            if x < min_x { min_x = x; }
            if x > max_x { max_x = x; }
            if y < min_y { min_y = y; }
            if y > max_y { max_y = y; }
        }
    }

    // "Sensitivity" Threshold: 50 changed points required to trigger
    if diff_count > 50 {
        let w = if max_x > min_x { max_x - min_x } else { 0 };
        let h = if max_y > min_y { max_y - min_y } else { 0 };

        Some(MotionROI {
            x: min_x as u32,
            y: min_y as u32,
            w: w as u32,
            h: h as u32,
        })
    } else {
        None
    }
}