defmodule SwarmBrain.Cortex do
  @moduledoc """
  The Central Processing Unit.
  Wraps the Neural Network in a GenServer.
  """
  use GenServer
  require Logger
  # ADD THIS ALIAS so we can use the struct
  alias SwarmBrain.Observation

  # DEFINING THE RULES FOR PLUGINS
  @callback analyze(binary()) :: map()

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def analyze(image_binary) do
    GenServer.call(__MODULE__, {:analyze, image_binary}, 10_000)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    Logger.info("🧠 Cortex Online. Loading Neural Pathways...")
    {:ok, %{model: nil}}
  end

  @impl true
  def handle_call({:analyze, image_binary}, _from, state) do
    # FIXED: Return a proper %Observation{} struct, not just a map.
    # This ensures it has all the keys (:image_binary, :lat, etc.) that Pipeline expects.

    dummy_prediction = %Observation{
      id: UUID.uuid4(),
      class: "target_dummy",
      confidence: 0.99,
      bbox: [10, 10, 50, 50],
      # We must include the image binary so Pipeline can strip it later without crashing
      image_binary: image_binary,
      timestamp: DateTime.utc_now()
    }

    {:reply, dummy_prediction, state}
  end
end
