defmodule SwarmBrain.Sensor.Proprioception do
  @moduledoc """
  The Fast-Twitch Muscle Fibers.
  Decouples physics (Proprioception) from high-level perception (Fusion).
  """
  alias SwarmBrain.Vision.{Server, Native}

  # --- ZERO-LATENCY READ (Kinematics) ---
  def get_kinematics do
    resource = Server.get_resource()

    if resource do
      # FIX: The NIF returns a Tuple {vx, vy, px, py}, NOT a binary.
      # Pass it through directly to Tracker.
      Native.get_fused_state(resource)
    else
      # Return a Tuple matching the success shape, not a Tensor
      {0.0, 0.0, 0.0, 0.0}
    end
  end

  # --- ZERO-LATENCY READ (Optical Flow Grid) ---
  # Returns a tensor of shape {200} representing the 10x10 grid (dx, dy)
  def get_optical_flow do
    resource = Server.get_resource()

    if resource do
      # Fetch 800 bytes (200 floats)
      case Native.get_flow_grid(resource) do
        bin when is_binary(bin) ->
          Nx.from_binary(bin, :f32)
        _ ->
          Nx.broadcast(0.0, {200}) |> Nx.as_type(:f32)
      end
    else
      Nx.broadcast(0.0, {200}) |> Nx.as_type(:f32)
    end
  end
end
