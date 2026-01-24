defmodule SwarmBrain.Formation do
  use GenServer
  require Logger
  alias SwarmBrain.Telemetry.Protocol

  # Safety: If no signal for 2 seconds, stop moving.
  @signal_timeout 2000

  defstruct [
    :current_vector,
    :formation_offset,
    :last_seen_ts
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Phoenix.PubSub.subscribe(SwarmBrain.PubSub, "radio:telemetry")
    initial_offset = Keyword.get(opts, :offset, %{x: 0, y: 0})

    {:ok, %__MODULE__{
      current_vector: %{heading: 0.0, velocity: 0.0},
      formation_offset: initial_offset,
      last_seen_ts: System.monotonic_time(:millisecond)
    }}
  end

  def handle_info({:telemetry_packet, binary_data, _rssi}, state) do
    case Protocol.decode(binary_data) do
      {:ok, _leader_vector} ->
        # Calculate new vector based on leader
        # For now, we just log that we heard the leader
        {:noreply, %{state | last_seen_ts: System.monotonic_time(:millisecond)}}

      {:error, _} ->
        {:noreply, state}
    end
  end

  def handle_info(:check_safety, state) do
    now = System.monotonic_time(:millisecond)
    if (now - state.last_seen_ts) > @signal_timeout do
      # FIXED: Logger.warn is deprecated
      Logger.warning("⚠️ Leader Lost. Engaging Hover.")
      {:noreply, %{state | current_vector: %{heading: state.current_vector.heading, velocity: 0.0}}}
    else
      {:noreply, state}
    end
  end
end
