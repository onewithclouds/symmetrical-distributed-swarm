defmodule SwarmBrain.Vision.Server do
  @moduledoc """
  The Cerebellum of the Vision System.
  Now equipped with a Self-Healing Watchdog (Auto-Bias).
  """
  use GenServer
  require Logger
  alias SwarmBrain.Vision.{Native, SharedBuffer}
  alias SwarmBrain.Cortex.Yolo

  @resource_key :swarm_vision_resource
  @tick_interval 33 # ~30 FPS
  @health_check_interval 30 # Check every 30 ticks (~1 second)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def get_resource, do: :persistent_term.get(@resource_key, nil)

  @impl true
  def init(_opts) do
    config = Application.get_env(:swarm_brain, :vision, [width: 640, height: 480])
    width = config[:width]
    height = config[:height]

    Logger.info("👁️ Vision.Server: Ignition. Booting Iron Lung...")

    # 1. ALLOCATE ARENA (Rust)
    resource = Native.init_state()
    :persistent_term.put(@resource_key, resource)

    # 2. START HEARTBEAT
    case Native.start_camera(resource, width, height) do
      :ok ->
        Logger.info("👁️ Vision.Server: Heartbeat Active.")
        schedule_tick()
        {:ok, %{
          resource: resource,
          active_inferences: 0,
          max_concurrency: 1,
          tick_count: 0
        }}

      error ->
        Logger.error("❌ Vision.Server: Primary Ignition Failed: #{inspect(error)}")
        {:stop, :camera_ignition_failure}
    end
  end

  # --- THE WATCHDOG LOOP ---

  @impl true
  def handle_info(:tick, state) do
    # 1. Perform Health Check every second (~30 ticks)
    new_tick_count = state.tick_count + 1

    if rem(new_tick_count, @health_check_interval) == 0 do
      check_physiology!(state.resource)
    end

    # 2. Process Vision (Backpressure Control)
    if state.active_inferences < state.max_concurrency do
      case SharedBuffer.get_vision_tensor() do
        {:ok, tensor} ->
          async_inference(tensor)
          schedule_tick()
          {:noreply, %{state | active_inferences: state.active_inferences + 1, tick_count: new_tick_count}}

        _ ->
          schedule_tick()
          {:noreply, %{state | tick_count: new_tick_count}}
      end
    else
      # System saturated; skip frame
      schedule_tick()
      {:noreply, %{state | tick_count: new_tick_count}}
    end
  end

  def handle_info(:inference_complete, state) do
    {:noreply, %{state | active_inferences: max(0, state.active_inferences - 1)}}
  end

  # --- PRIVATE HELPERS ---

  defp check_physiology!(resource) do
    # [Point 2: The Watchdog]
    # We call the Rust NIF to see if the process is alive
    case Native.check_health(resource) do
      :ok ->
        :ok # Pulse detected.

      :error ->
        Logger.warning("👻 Vision.Server: BRAIN-STEM DEATH DETECTED. Triggering Reset...")
        # Trigger Supervisor Restart (Power Cycle)
        exit(:camera_failure)
    end
  end

  defp async_inference(tensor) do
    parent = self()
    Task.Supervisor.start_child(SwarmBrain.Cortex.Supervisor, fn ->
      results = Yolo.analyze(tensor)
      SwarmBrain.Blackboard.update_vision(results, %{})
      send(parent, :inference_complete)
    end)
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_interval)

  @impl true
  def terminate(_reason, _state) do
    :persistent_term.erase(@resource_key)
  end
end
