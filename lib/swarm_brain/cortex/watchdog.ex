defmodule SwarmBrain.Cortex.Watchdog do
  use GenServer
  require Logger

  @high 0.75
  @low 0.35
  @lock_duration 5000
  @latency_warn_threshold 200 # ms

  def start_link(_), do: GenServer.start_link(__MODULE__, %{mode: :high_accuracy, locked_until: 0}, name: __MODULE__)
  def init(state), do: {:ok, state}

  def input_confidence(score), do: GenServer.cast(__MODULE__, {:tick, score})
  def input_imu(g_force), do: GenServer.cast(__MODULE__, {:imu_spike, g_force})

  # [NEW] Latency Telemetry
  def report_latency(nanos), do: GenServer.cast(__MODULE__, {:latency, nanos})

  # --- HANDLERS ---

  def handle_cast({:latency, nanos}, state) do
    ms = System.convert_time_unit(nanos, :native, :millisecond)

    if ms > @latency_warn_threshold do
      Logger.warning("🐢 High Latency Detected: #{ms}ms")
    end

    # Future expansion: If latency stays high, downgrade model automatically
    {:noreply, state}
  end

  def handle_cast({:imu_spike, g_force}, state) when g_force > 2.0 do
    Logger.warning("G-Force Spike (#{g_force}G). OVERRIDE: Forcing High Accuracy.")
    SwarmBrain.Switchboard.swap_model(SwarmBrain.Cortex.ResNet)
    lock_time = System.monotonic_time(:millisecond) + @lock_duration
    {:noreply, %{state | mode: :high_accuracy, locked_until: lock_time}}
  end

  def handle_cast({:tick, score}, state) do
    now = System.monotonic_time(:millisecond)
    if now < state.locked_until do
      {:noreply, state}
    else
      handle_hysteresis(score, state)
    end
  end

  defp handle_hysteresis(score, %{mode: :high_accuracy} = state) when score < @low do
    Logger.info("Confidence dropping. Engaging Power Save.")
    SwarmBrain.Switchboard.swap_model(SwarmBrain.Cortex.MobileNet)
    {:noreply, %{state | mode: :power_save}}
  end

  defp handle_hysteresis(score, %{mode: :power_save} = state) when score > @high do
    Logger.info("Confidence High. Restoring Full Fidelity.")
    SwarmBrain.Switchboard.swap_model(SwarmBrain.Cortex.ResNet)
    {:noreply, %{state | mode: :high_accuracy}}
  end

  defp handle_hysteresis(_, state), do: {:noreply, state}
end
