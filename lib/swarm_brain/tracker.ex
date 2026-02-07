defmodule SwarmBrain.Tracker do
  use GenServer
  require Logger
  # [NEW] Added Proprioception to aliases
  alias SwarmBrain.{Actor.Network, Sensor.Fusion, Sensor.Proprioception, Vision.Server}

  @interval 33

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    Logger.info("🧠 Tracker: RL Pilot Engaging...")
    params = Network.init_random_params()
    schedule_loop()
    {:ok, %{policy: params, tick: 0}}
  end

  def handle_info(:control_loop, state) do
    # 1. Check if System is Online
    if Server.get_resource() do
      # A. PROPRIOCEPTION (Rust Physics - 4 inputs)
      physics_state = Proprioception.get_kinematics()

      # B. FUSION (Visual Target)
      _target = Fusion.get_visual_target()

      # C. FLOW (REAL DATA - 200 inputs)
      # [UPDATED] We now fetch the 10x10 vector grid from Rust
      flow_grid = Proprioception.get_optical_flow()

      # D. INTENT (3 inputs)
      intent = Nx.tensor([1.0, 0.0, 0.0], type: :f32)

      # Inference
      # [NOTE] Ensure flow_grid is flat. Nx.from_binary is flat by default.
      input = Nx.concatenate([physics_state, flow_grid, intent]) |> Nx.new_axis(0)
      action = Network.predict(state.policy, input)

      if rem(state.tick, 30) == 0 do
        Logger.debug("🧠 Pilot: #{inspect(Nx.to_flat_list(action), charlists: :as_lists)}")
      end
    end

    schedule_loop()
    {:noreply, %{state | tick: state.tick + 1}}
  end

  defp schedule_loop, do: Process.send_after(self(), :control_loop, @interval)
end
