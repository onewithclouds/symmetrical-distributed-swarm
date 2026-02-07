defmodule SwarmBrain.Telemetry.Monitor do
  use GenServer
  require Logger

  # Indices for atomic array
  @clean_idx 1
  @clipped_idx 2

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_) do
    # 1. Atomic Counters (Low-Level Mitigation)
    # Create a persistent atomic array (2 unsigned integers)
    ref = :atomics.new(2, signed: false)
    :persistent_term.put(:telemetry_monitor_ref, ref)

    :timer.send_interval(1000, :tick)
    {:ok, %{ref: ref}}
  end

  # Public API - Called by Guard
  def log_packet(:ok) do
    ref = :persistent_term.get(:telemetry_monitor_ref)
    :atomics.add(ref, @clean_idx, 1)
  end

  def log_packet(:error) do
    ref = :persistent_term.get(:telemetry_monitor_ref)
    :atomics.add(ref, @clipped_idx, 1)
  end

  def handle_info(:tick, %{ref: ref} = state) do
    # Read and Reset atomically
    clean = :atomics.exchange(ref, @clean_idx, 0)
    clipped = :atomics.exchange(ref, @clipped_idx, 0)

    total = clean + clipped

    if total > 0 do
      distortion = clipped / total
      if distortion > 0.10 do
        # 2. Fire-and-Forget Logging (Strategic Mitigation)
        Task.start(fn ->
          Logger.warning("Harmonic Distortion High: #{Float.round(distortion * 100, 2)}% packet loss.")
        end)
      end
    end
    {:noreply, state}
  end
end
