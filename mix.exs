defmodule SwarmBrain.MixProject do
  use Mix.Project

  def project do
    [
      app: :swarm_brain,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      rustler_crates: [
        swarm_brain_tactician: [],
        swarm_brain_nms: [],
        swarm_vision: [mode: :release]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :os_mon, :mnesia],
      mod: {SwarmBrain.Application, []}
    ]
  end

  defp deps do
    [
      # --- The Nervous System ---
      {:phoenix_pubsub, "~> 2.1"},
      {:horde, "~> 0.9.0"},
      {:elixir_uuid, "~> 1.2"},
      {:rustler, "~> 0.30"},
      {:evision, "~> 0.1"},

      # [NEW] Hive Mind Protocols
      {:libcluster, "~> 3.3"},  # UDP Gossip Discovery
      {:delta_crdt, "~> 0.6"},  # Anti-Entropy Data Sync

      # --- The Hardware Interface ---
      {:circuits_uart, "~> 1.5"},

      # --- The Vision Cortex ---
      {:bumblebee, "~> 0.6.0"},
      {:exla, "~> 0.9.0"},
      {:nx, "~> 0.9.0"},
      {:axon, "~> 0.7.0"},
      {:ortex, "~> 0.1.9"}
    ]
  end
end
