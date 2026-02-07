defmodule SwarmBrain.Vision.Server do
  @moduledoc """
  The Heart of the Vision System.
  It owns the Rust Resource but shares it via :persistent_term for zero-latency access.
  """
  use GenServer
  require Logger
  alias SwarmBrain.Vision.{Native, SharedBuffer}
  alias SwarmBrain.Cortex.Yolo

  # The Global Key for the Rust Handle
  @resource_key :swarm_vision_resource
  @tick_interval 33

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # --- PUBLIC API (The Zero-Latency Lookup) ---
  def get_resource do
    :persistent_term.get(@resource_key, nil)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:swarm_brain, :vision, [width: 640, height: 480])
    width = config[:width]
    height = config[:height]

    Logger.info("👁️ Vision.Server: Booting Iron Lung...")

    # 1. ALLOCATE MEMORY (Rust Side)
    resource = Native.init_state()

    # 2. SHARE THE KEY (The Handover)
    :persistent_term.put(@resource_key, resource)

    # 3. IGNITE CAMERA
    # Note: User confirmed /dev/video1 is the target
    case Native.start_camera(resource, width, height) do
      :ok ->
        Logger.info("👁️ Vision.Server: Camera Online.")
        schedule_tick()
        {:ok, %{resource: resource, active_inferences: 0, max_concurrency: 1}}

      error ->
        Logger.error("❌ Failed to start camera: #{inspect(error)}")
        {:stop, error}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :persistent_term.erase(@resource_key)
  end

  # --- THE HEARTBEAT (YOLO SCHEDULING) ---
  @impl true
  def handle_info(:tick, state) do
    if state.active_inferences < state.max_concurrency do
      case SharedBuffer.get_vision_tensor() do
        {:ok, tensor} ->
          async_inference(tensor)
          schedule_tick()
          {:noreply, %{state | active_inferences: state.active_inferences + 1}}

        _ ->
          schedule_tick()
          {:noreply, state}
      end
    else
      schedule_tick()
      {:noreply, state}
    end
  end

  def handle_info(:inference_complete, state) do
    {:noreply, %{state | active_inferences: max(0, state.active_inferences - 1)}}
  end

  defp async_inference(tensor) do
    parent = self()
    Task.Supervisor.start_child(SwarmBrain.Cortex.Supervisor, fn ->
      results = Yolo.analyze(tensor)
      SwarmBrain.Blackboard.update_vision([results], %{source: :webcam})
      send(parent, :inference_complete)
    end)
  end

  # [FIX] This was missing!
  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_interval)
end
