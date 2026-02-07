defmodule SwarmBrain.Pipeline do
  use GenServer
  require Logger
  alias SwarmBrain.Observation

  # Threshold: If signal is worse than -85dBm, stop sending JPEGs.
  @rssi_emergency_threshold -85

  def start_link(_opts) do
    # FIXED: Initialize with a default RSSI of -60 (Good Signal)
    GenServer.start_link(__MODULE__, %{rssi: -60}, name: __MODULE__)
  end

  def init(state) do
    Phoenix.PubSub.subscribe(SwarmBrain.PubSub, "radio:telemetry")
    {:ok, state}
  end

  # Receive Data + Signal Strength
  def handle_info({:telemetry_packet, _data, rssi}, state) do
    # Update local state with signal quality
    {:noreply, Map.put(state, :rssi, rssi)}
  end

  @doc """
  Main Entry Point: The Eye sees something.
  """
  def process_visual_data(image_binary) do
    GenServer.cast(__MODULE__, {:process_image, image_binary})
  end

  def handle_cast({:process_image, image}, state) do
    # 1. Decide WHERE to process (Horde / Global Grid)
    processor_pid = find_best_cortex()

    # Capture RSSI safely before spawning task
    current_rssi = Map.get(state, :rssi, -60)

    # 2. Decide WHAT to send back (Dynamic Compression)
    # If we are the processor, we do the work.
    Task.start(fn ->
      # Let it crash. Isolate the heavy math.
      result = GenServer.call(processor_pid, {:analyze, image}, 15_000)
      handle_analysis_result(result, current_rssi)
    end)

    {:noreply, state}
  end

  # --- The "Horde" Global Grid Lookup ---
  defp find_best_cortex do
    # Ask Horde Registry for a process named "GlobalCortex"
    # If it exists (e.g., on the Mother Ship), use it.
    # If not, fall back to our local Cortex.
    case Horde.Registry.lookup(SwarmBrain.HordeRegistry, "GlobalCortex") do
      [{pid, _} | _] -> pid
      [] -> SwarmBrain.Cortex # Local Atom
    end
  end

  # --- Dynamic Compression Logic ---
defp handle_analysis_result(observation, rssi) do

  # 1. Broadcast to the Nervous System (Tracker, UI, etc.)
    Phoenix.PubSub.broadcast(
      SwarmBrain.PubSub,
      "vision:analysis",
      {:visual_contact, observation}
    )

    payload =
      if rssi < @rssi_emergency_threshold do
        # Emergency Mode: Prune everything except Class ID and Coordinates
        Observation.prune_payload(observation, :emergency)
      else
        # Full Mode: Include Metadata, Confidence scores, etc.
        Observation.prune_payload(observation, :full)
      end

    # Send to persistence / ground station
    SwarmBrain.Persistence.log(payload)
  end
end
