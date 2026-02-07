defmodule SwarmBrain.Application do
  use Application
  require Logger

  def start(_type, _args) do
    # 1. Configuration Bias
    topologies = Application.get_env(:libcluster, :topologies) || []
    cortex = Application.get_env(:swarm_brain, :cortex_module)

    # --- SYNCHRONOUS BRAIN LOADING ---
    Code.ensure_loaded(cortex)

    if function_exported?(cortex, :init, 0) do
      Logger.info("🧠 Pre-loading Cortex: #{inspect(cortex)}")
      cortex.init()
    else
      Logger.warning("⚠️ Cortex #{inspect(cortex)} has no init/0 callback.")
    end

    # ---------------------------------------

    children = [
      # 1. Cluster Manager
      {Cluster.Supervisor, [topologies, [name: SwarmBrain.ClusterSupervisor]]},

      # 2. Nervous System
      {Phoenix.PubSub, name: SwarmBrain.PubSub},

      # 3. The Spinal Cord
      {SwarmBrain.Hardware.Spine, []},

      # 4. Model Switching Logic
      {SwarmBrain.Switchboard, cortex},

      # 5. Shared Consciousness
      {SwarmBrain.Blackboard, []},

      # [RESTORED] The Inner Ear (Supervised Process)
      {SwarmBrain.Sensor.Fusion, []},

      # 6. Supervision for Async Tasks
      {Task.Supervisor, name: SwarmBrain.Cortex.Supervisor},

      # 7. The Iron Lung (Vision System)
      {SwarmBrain.Vision.Server, []},

      # 8. The Pilot (RL Agent)
      {SwarmBrain.Tracker, []}
    ]

    opts = [strategy: :one_for_one, name: SwarmBrain.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # 3. JIT WARMING (Async)
      warm_up_jit(cortex)
      {:ok, pid}
    end
  end

  defp warm_up_jit(cortex) do
    Logger.info("🔥 Ignition Sequence: Warming up Neural Pathways...")

    Task.start(fn ->
      # 1. Warm Up Vision (YOLO)
      Logger.debug("... Warming Eyes (Yolo)")
      dummy_image = Nx.broadcast(0, {480, 640, 3}) |> Nx.as_type({:u, 8})

      try do
        cortex.analyze(dummy_image)
      rescue
        e -> Logger.warning("Vision Warm-up skipped: #{inspect(e)}")
      end

      # 2. Warm Up Pilot (RL Network)
      Logger.debug("... Warming Pilot (RL Network)")

      # Dummy input matching the Tracker's shape {1, 207}
      dummy_state = Nx.broadcast(0.0, {1, 207}) |> Nx.as_type(:f32)

      try do
        SwarmBrain.Actor.Network.predict(
          SwarmBrain.Actor.Network.init_random_params(),
          dummy_state
        )
      rescue
        e -> Logger.warning("Pilot Warm-up skipped: #{inspect(e)}")
      end

      Logger.info("✅ System Ready.")
    end)
  end
end
