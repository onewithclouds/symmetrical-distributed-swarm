defmodule SwarmBrain.Vision.Behaviour do
  @moduledoc "The Constitutional Contract for the Vision System."

  @callback start_camera(width :: integer(), height :: integer()) :: :ok | {:error, any()}
  @callback capture_frame() :: binary() | {:error, atom()}
  @callback to_binary(data :: any()) :: binary()
end
