defmodule SwarmBrain.Vision.Native do
  @moduledoc """
  The Iron Lung Interface.
  Acts as the bridge to the Rust 'swarm_native' crate.
  """
  use Rustler, otp_app: :swarm_brain, crate: "swarm_native"

  # --- 1. LIFECYCLE ---
  def init_state, do: error()

  # Arity 3: width, height, threshold
  def init_retina(_width, _height, _threshold), do: error()

  # Arity 3: resource, width, height
  def start_camera(_resource, _width, _height), do: error()

  # --- 2. SENSORS (ATOMIC) ---

  def get_latest_frame(_resource), do: error()
  def get_fused_state(_resource), do: error()
  def get_flow_grid(_resource), do: error()

  # --- 3. LOGIC (RETINA) ---

  # Arity 2: resource, frame_binary
  def detect_change(_resource, _frame), do: error()

  # --- 4. LEGACY STUBS (FIXED) ---

  # [FIX] Removed _env. Arity is now 4 (id, x, y, h).
  def update_spatial_state(_id, _x, _y, _h), do: error()

  # [FIX] Removed _env. Arity is now 1 (id).
  def get_spatial_state(_id), do: error()

  # [FIX] Removed _env. Arity is now 0.
  def setup_queryable(), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
