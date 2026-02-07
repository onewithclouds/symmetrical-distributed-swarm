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
      bin = Native.get_fused_state(resource)
      Nx.from_binary(bin, :f32)
    else
      Nx.tensor([0.0, 0.0, 0.0, 0.0], type: :f32)
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
