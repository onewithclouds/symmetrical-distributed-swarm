defmodule SwarmBrain.Vision.SharedBuffer do
  @moduledoc "Interface for Zero-Copy tensor creation with Neuromorphic Gating."
  require Logger
  alias SwarmBrain.Vision.{Server, Native}

  @config Application.compile_env(:swarm_brain, :vision, [width: 640, height: 480])
  @width @config[:width]
  @height @config[:height]
  @channels 3
  @expected_size @width * @height * @channels

  def get_vision_tensor(_opts \\ []) do
    # 1. Get Resource Handle
    resource = Server.get_resource()

    if resource do
      # 2. Atomic Fetch from Rust
      case Native.get_latest_frame(resource) do
        :no_change ->
          :no_change

        raw_binary when is_binary(raw_binary) ->
          if byte_size(raw_binary) == @expected_size do
            # [FIX] Inflate Binary to Tensor
            # The Cortex expects specific shape {H, W, C}
            Nx.from_binary(raw_binary, :u8)
            |> Nx.reshape({@height, @width, @channels})
            |> then(&{:ok, &1}) # Wrap in success tuple
          else
            # Handle startup transient state (empty buffer)
            if byte_size(raw_binary) == 0 do
              {:error, :buffer_empty}
            else
              Logger.error("CRITICAL: Buffer Size Mismatch! Expected #{@expected_size}, Got #{byte_size(raw_binary)}")
              {:error, :memory_corruption}
            end
          end

        _ ->
          {:error, :unknown_return}
      end
    else
      {:error, :vision_offline}
    end
  end
end
