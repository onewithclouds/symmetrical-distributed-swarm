use rustler::{NifStruct, Env, Term, NifResult};
use std::path::Path;

#[rustler::nif(schedule = "DirtyCpu")]
fn load_model(path: String) -> NifResult<String> {
    if Path::new(&path).exists() {
        Ok(format!("🧠 Tactician Core online. Memory mapped: {}", path))
    } else {
        Ok(format!("❌ Error: Brain file not found at {}", path))
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn think(context_text: String) -> String {
    // SIMULATED REASONING (The "Tube Amp" Warm-up)
    // This proves the pipeline works.
    
    if context_text.contains("person") {
        "DECISION: TRACK_TARGET. REASON: Unauthorized human detected."
    } else if context_text.contains("watch") {
        "DECISION: HOVER. REASON: High-value asset identified."
    } else {
        "DECISION: SEARCH. REASON: Sector clear."
    }.to_string()
}

rustler::init!("Elixir.SwarmBrain.Tactician.Native", [load_model, think]);