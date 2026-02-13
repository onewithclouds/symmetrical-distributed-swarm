// native/swarm_native/src/vision/camera.rs

use std::io::Read;
use std::process::{Command, Stdio};
use std::sync::atomic::Ordering;
use std::thread;
use std::time::Instant;

use crate::state::arena::{SwarmState, FRAME_SIZE, FRAME_WIDTH, FRAME_HEIGHT};
use crate::vision::math; 

// [CORRECT] Taking state by value (SwarmState), not reference or Arc wrapper
pub fn spawn_heartbeat(state: SwarmState, width: u32, height: u32) {
    // OPTIMIZATION: Removed the redundant .clone() lines here.
    // Since we move 'state' into the thread below, we can access 
    // state.memory, state.physiology, etc. directly inside the loop.

    thread::spawn(move || {
        // 1. Ignite FFmpeg
        let child = Command::new("ffmpeg")
            .args(&[
                "-f", "v4l2", "-framerate", "30", "-video_size", &format!("{}x{}", width, height),
                "-i", "/dev/video1", 
                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .expect("Failed to ignite FFmpeg heartbeat");

        // 2. Health Monitor: Store the child process handle
        {
            // [CORRECT] Accessing the new Arc<Mutex<>> defined in arena.rs
            let mut process_lock = state.child_process.lock().unwrap();
            *process_lock = Some(child);
        }

        // 3. Re-acquire stdout for the hot loop
        let mut stdout = {
            let mut lock = state.child_process.lock().unwrap();
            lock.as_mut().unwrap().stdout.take().unwrap()
        };

        let mut last_time = Instant::now();
        let mut current_w_idx = 0;
        let mut local_grid = [0.0f32; 200];

        // Thread-local previous frame buffer (The Evolutionary Step)
        let mut prev_frame = vec![0u8; FRAME_SIZE];

        // 4. The Iron Lung Loop
        // [CLEANUP] Access state directly instead of using the old _ref variables
        while state.running.load(Ordering::Acquire) == 1 {
            
            // Triple Buffer Logic
            let r_idx = state.memory.ready_idx.load(Ordering::Acquire);
            let next_w_idx = (current_w_idx + 1) % 3;
            let final_w_idx = if next_w_idx == r_idx { (next_w_idx + 1) % 3 } else { next_w_idx };

            let slot = &state.memory.slots[final_w_idx];

            {
                let mut data = slot.data.lock().unwrap();
                
                if stdout.read_exact(&mut data).is_err() { break; }

                let (dx, dy) = math::calculate_optical_flow(
                    &data, 
                    &prev_frame, 
                    FRAME_WIDTH, 
                    FRAME_HEIGHT, 
                    &mut local_grid
                );
                
                let dt = last_time.elapsed().as_secs_f32();
                last_time = Instant::now();
                
                // Direct access to physiology
                let vx = state.physiology.vx.load() * 0.7 + dx * 0.3;
                let vy = state.physiology.vy.load() * 0.7 + dy * 0.3;
                
                state.physiology.vx.store(vx);
                state.physiology.vy.store(vy);
                state.physiology.px.store(state.physiology.px.load() + vx * dt);
                state.physiology.py.store(state.physiology.py.load() + vy * dt);

                if let Ok(mut g) = state.flow_grid.write() {
                    g.copy_from_slice(&local_grid);
                }
                
                prev_frame.copy_from_slice(&data);
            }

            state.memory.ready_idx.store(final_w_idx, Ordering::Release);
            state.memory.write_idx.store(final_w_idx, Ordering::Release);
            current_w_idx = final_w_idx;
        }
    });
}