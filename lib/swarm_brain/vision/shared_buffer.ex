defmodule SwarmBrain.Vision.SharedBuffer do
  @moduledoc "Interface for Zero-Copy tensor creation."
  require Logger
  alias SwarmBrain.Vision.{Server, Native}

  # Ensure these match native/swarm_native/src/state/arena.rs
  # We read config at compile time to avoid runtime lookup costs in the hot loop
  @config Application.compile_env(:swarm_brain, :vision, [width: 640, height: 480])
  @width @config[:width]
  @height @config[:height]
  @channels 3
  @expected_size @width * @height * @channels

  @doc """
  Fetches the current frame from the Iron Lung and inflates it into an Nx Tensor.
  Returns {:ok, tensor} or {:error, reason}.
  """
  def get_vision_tensor(_opts \\ []) do
    resource = Server.get_resource()

    if resource do
      # 1. Atomic Fetch (Always returns Binary)
      # The Iron Lung guarantees this is never nil and never empty (pre-allocated).
      raw_binary = Native.get_latest_frame(resource)

      # 2. Safety Check
      if byte_size(raw_binary) == @expected_size do

        # 3. Inflate to Tensor
        # Note: At boot, this may be an all-black tensor (zeros)
        # We use u8 (0-255) for raw RGB data.
        Nx.from_binary(raw_binary, :u8)
        |> Nx.reshape({@height, @width, @channels})
        |> then(&{:ok, &1})

      else
        # This branch catches "Cosmic Ray" memory corruption or config mismatches
        Logger.error("CRITICAL: Buffer Mismatch! Rust sent #{byte_size(raw_binary)}, Expected #{@expected_size}")
        {:error, :memory_corruption}
      end
    else
      # The Rust NIF hasn't been loaded into the Persistent Term yet
      {:error, :resource_not_ready}
    end
  end
end
