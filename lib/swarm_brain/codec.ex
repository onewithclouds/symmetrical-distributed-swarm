defmodule SwarmBrain.Telemetry.Codec do
  @moduledoc """
  Pure functional core for bit-level swarm communications.
  Optimized for minimal bandwidth using Erlang binary pattern matching.
  """

  @doc "Packs vitals into 3 bytes: 10b Heading, 8b Velocity, 6b Battery"
  def encode_vitals(%{heading: h, velocity: v, battery: b}) do
    # Clamp values to prevent bit-overflow crashes
    h_int = h |> round() |> rem(360)
    v_int = min(v, 255)
    b_int = min(b, 100)

    <<h_int::size(10), v_int::size(8), b_int::size(6)>>
  end

  @doc "Decodes the 24-bit vital packet."
  def decode_vitals(<<heading::size(10), velocity::size(8), battery::size(6)>>) do
    %{
      heading: heading,
      velocity: velocity,
      battery: battery
    }
  end
end
