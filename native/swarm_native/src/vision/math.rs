// native/swarm_native/src/vision/math.rs

/// THE INSECT EYE (Optical Flow Core)
/// Tactic 3: Zero-Copy Math.
/// We treat the RGB buffer as a flat signal and sample the 'Green' channel 
/// (index 1) for the highest luminance signal-to-noise ratio.

#[inline(always)]
pub fn calculate_optical_flow(
    current: &[u8],
    prev: &[u8],
    width: usize,
    height: usize,
    grid_out: &mut [f32; 200], // 10x10 grid, 2 floats per point
) -> (f32, f32) {
    let mut total_dx = 0;
    let mut total_dy = 0;
    let mut points = 0;

    let step_x = width / 10;
    let step_y = height / 10;
    
    // Safety Margin: Search Range (4) + Block Radius (4) + Padding
    let margin = 20; 

    for g_y in 0..10 {
        for g_x in 0..10 {
            // Grid point coordinates
            let x = margin + g_x * step_x;
            let y = margin + g_y * step_y;
            
            // Analyze the 8x8 block at this position
            let (dx, dy, score) = find_best_block_match(current, prev, x, y, width, 4);

            let idx = (g_y * 10 + g_x) * 2;
            grid_out[idx] = dx as f32;
            grid_out[idx + 1] = dy as f32;

            // Strict threshold: SAD score per pixel must be low
            // 8x8 = 64 pixels. Score < 800 means avg error < 12.5 per pixel
            if score < 800 { 
                total_dx += dx;
                total_dy += dy;
                points += 1;
            }
        }
    }

    if points > 0 {
        (total_dx as f32 / points as f32, total_dy as f32 / points as f32)
    } else {
        (0.0, 0.0)
    }
}

/// TRUE Block Matcher (8x8 Kernel)
/// Now using an inner loop so LLVM can actually vectorize the subtraction.
#[inline(always)]
fn find_best_block_match(
    current: &[u8],
    prev: &[u8],
    cx: usize,      // Center X
    cy: usize,      // Center Y
    width: usize,
    range: i32,     // Search range (e.g., +/- 4 pixels)
) -> (i32, i32, u32) {
    let mut best_sad = u32::MAX;
    let mut best_dx = 0;
    let mut best_dy = 0;

    // 1. Iterate through search candidates (The "Motion Vector" candidates)
    for dy in -range..=range {
        for dx in -range..=range {
            
            let mut sad: u32 = 0;

            // 2. Iterate through the 8x8 Block (The "Texture Matcher")
            // We compare a 8x8 patch centered at (cx, cy) in 'prev'
            // to a 8x8 patch centered at (cx+dx, cy+dy) in 'current'
            for by in 0..8 {
                // Optimization: Pre-calculate row pointers
                let p_row_y = cy + by - 4;
                let c_row_y = (cy as i32 + dy + by as i32 - 4) as usize;
                
                let p_row_offset = p_row_y * width * 3; // stride * 3 channels
                let c_row_offset = c_row_y * width * 3;

                for bx in 0..8 {
                    let p_x = cx + bx - 4;
                    let c_x = (cx as i32 + dx + bx as i32 - 4) as usize;

                    // Sample GREEN channel (index 1)
                    let p_idx = p_row_offset + p_x * 3 + 1;
                    let c_idx = c_row_offset + c_x * 3 + 1;

                    let p_val = prev[p_idx] as i32;
                    let c_val = current[c_idx] as i32;

                    sad += (p_val - c_val).abs() as u32;
                }
            }

            // 3. Update Best Match
            if sad < best_sad {
                best_sad = sad;
                best_dx = dx;
                best_dy = dy;
            }
        }
    }

    (best_dx, best_dy, best_sad)
}