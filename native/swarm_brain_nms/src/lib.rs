use rustler::{NifStruct, Atom, Term};

#[derive(NifStruct, Clone, Debug)]
#[module = "SwarmBrain.Vision.Box"]
pub struct Rect {
    pub x1: f32,
    pub y1: f32,
    pub x2: f32,
    pub y2: f32,
    pub score: f32,
    pub label: String,
}

#[rustler::nif]
pub fn nms(boxes: Vec<Rect>, iou_threshold: f32) -> Vec<Rect> {
    let mut detections = boxes;

    // Optimization: Sort Ascending so .pop() gives the highest score efficiently
    detections.sort_by(|a, b| a.score.partial_cmp(&b.score).unwrap_or(std::cmp::Ordering::Equal));

    let mut kept = Vec::with_capacity(detections.len());

    while let Some(best) = detections.pop() {
        kept.push(best.clone());

        // Remove any remaining box that overlaps too much with 'best'
        // We iterate backwards to safely remove items
        detections.retain(|item| calculate_iou(&best, item) < iou_threshold);
    }
    
    kept
}

fn calculate_iou(a: &Rect, b: &Rect) -> f32 {
    let x_left = a.x1.max(b.x1);
    let y_top = a.y1.max(b.y1);
    let x_right = a.x2.min(b.x2);
    let y_bottom = a.y2.min(b.y2);

    if x_right < x_left || y_bottom < y_top {
        return 0.0;
    }

    let intersection_area = (x_right - x_left) * (y_bottom - y_top);
    let area_a = (a.x2 - a.x1) * (a.y2 - a.y1);
    let area_b = (b.x2 - b.x1) * (b.y2 - b.y1);

    intersection_area / (area_a + area_b - intersection_area)
}

rustler::init!("Elixir.SwarmBrain.Vision.NMS", [nms]);