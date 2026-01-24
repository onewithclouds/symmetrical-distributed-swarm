defmodule SwarmBrain.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Define the supervision tree
    children = [
      # 1. The Nervous System (PubSub)
      # Must start first so Radio and Formation can talk.
      {Phoenix.PubSub, name: SwarmBrain.PubSub},

      # 2. The Distributed Mind (Horde)
      # These allow us to find processes across the cluster (Drone A finds Drone B).
      {Horde.Registry, [name: SwarmBrain.HordeRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: SwarmBrain.HordeSupervisor, strategy: :one_for_one]},

      # Blackbox telemetry
      SwarmBrain.Persistence,

      # 3. The Discovery Service (Cluster Connectivity)
      # Finds other nodes via UDP gossip or WiFi.
      SwarmBrain.Discovery,

      # 4. The Hardware Interface (Radio)
      # Starts listening to UART immediately.
      SwarmBrain.Antenna,

      # 5. The Logic Core
      # Pipeline: Decides what to do with images.
      # Formation: Decides how to fly based on Radio packets.
      SwarmBrain.Pipeline,
      SwarmBrain.Formation,

      # 6. The Eye (Camera)
      # Can be disabled via config for "Blind" nodes.
      # SwarmBrain.Eye,

      # 7. The Cortex (Brain)
      # This might be a heavy process (NX/Axon), so we start it last.
      {SwarmBrain.Cortex, name: SwarmBrain.Cortex}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SwarmBrain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
