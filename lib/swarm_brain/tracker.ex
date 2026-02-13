defmodule SwarmBrain.Tracker do
  use GenServer
  require Logger
  alias SwarmBrain.{Actor.Network, Sensor.Fusion, Sensor.Proprioception, Vision.Server}

  @interval 33

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    Logger.info("🧠 Tracker: RL Pilot Engaging...")
    # Use the new Axon struct if possible, or suppress warning if just a map
    params = Network.init_random_params()
    schedule_loop()
    {:ok, %{policy: params, tick: 0}}
  end

  def handle_info(:control_loop, state) do
    if Server.get_resource() do

      # --- A. PROPRIOCEPTION (The Fix) ---
      # Rust returns a Tuple: {vx, vy, px, py}
      # We MUST unpack it and wrap it in a List [] for Nx.tensor
      {vx, vy, px, py} = Proprioception.get_kinematics()
      physics_state = Nx.tensor([vx, vy, px, py], type: :f32)

      # --- B. FUSION ---
      _target = Fusion.get_visual_target()

      # --- C. FLOW (Optical Flow Grid) ---
      # This IS a binary from Rust, so Nx.from_binary is correct here.
      flow_raw = Proprioception.get_optical_flow()

      flow_grid = case flow_raw do
        %Nx.Tensor{} -> flow_raw
        bin when is_binary(bin) -> Nx.from_binary(bin, :f32)
        _ -> Nx.broadcast(0.0, {200}) # Fallback safety
      end

      # --- D. INTENT ---
      intent = Nx.tensor([1.0, 0.0, 0.0], type: :f32)

      # --- INFERENCE ---
      # Concatenate: Physics (4) + Flow (200) + Intent (3) = 207 Inputs
      # We flatten flow_grid just in case shape is weird
      input = Nx.concatenate([
        physics_state,
        Nx.flatten(flow_grid),
        intent
      ])
      |> Nx.new_axis(0) # Batch size of 1

      _action = Network.predict(state.policy, input)

      # Logger.debug("🧠 Tracker: Tick #{state.tick} | Px: #{px}")

      schedule_loop()
      {:noreply, %{state | tick: state.tick + 1}}
    else
      # Iron Lung not ready yet
      schedule_loop()
      {:noreply, state}
    end
  end

  defp schedule_loop, do: Process.send_after(self(), :control_loop, @interval)
end
