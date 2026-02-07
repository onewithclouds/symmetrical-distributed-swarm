
defmodule SwarmBrain.Formation do
  use GenServer
  require Logger


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


  def handle_info({:udp, _socket, _ip, _port, binary_data}, state) do
    # FIX: The Codec returns a map directly, not a tuple.
    # We catch crashes using a try/rescue block if the data is malformed,
    # or rely on the supervisor to restart us (the "Class A" approach).

    vitals = SwarmBrain.Telemetry.Codec.decode_vitals(binary_data)

    # Update state based on the raw map
    new_state = %{state |
      heading: vitals.heading,
      velocity: vitals.velocity
    }

    # Logic to adjust formation based on new vitals...
    {:noreply, new_state}
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
