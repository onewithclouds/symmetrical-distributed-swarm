defmodule SwarmBrain.Blackboard do
  @moduledoc """
  The Distributed Hive Mind.
  Synchronizes the 'Vision Summary' across all nodes via CRDT.
  """
  use GenServer
  require Logger

  @sync_interval 50

  defstruct [
    :crdt,
    target_class: "none",
    target_position: nil,
    mission_status: :search,
    swarm_census: 0
  ]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    Logger.info("📡 Blackboard: Initializing Hive Connectivity...")

    # 1. Start CRDT (Conflict-free Replicated Data Type)
    {:ok, crdt_pid} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: @sync_interval)

    # 2. Monitor Nodes (Auto-discovery)
    :net_kernel.monitor_nodes(true)
    update_neighbors(crdt_pid)

    {:ok, %__MODULE__{crdt: crdt_pid}}
  end

  # --- API ---

  def update_vision(summary, _meta) do
    GenServer.cast(__MODULE__, {:update_local_vision, summary})
  end

  # --- CALLBACKS ---

  def handle_cast({:update_local_vision, summary}, state) do
    # STRICT MODE: We expect 'summary' to be a Map %{label: "...", ...}
    # The crash proved we are receiving a single Map, not a List.

    # 1. Hive Sync
    # We broadcast our local summary to the rest of the swarm.
    DeltaCrdt.put(state.crdt, :vision_summary, %{
      node: Node.self(),
      label: summary.label,
      confidence: summary.confidence
    })

    # 2. Local Reflex
    # Pass the full data to Fusion for local targeting logic
    send(SwarmBrain.Sensor.Fusion, {:visual_contact, summary})

    {:noreply, state}
  end

  # Handle Node Join/Leave events from :net_kernel
  def handle_info({:nodeup, _node}, state) do
    update_neighbors(state.crdt)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node}, state) do
    update_neighbors(state.crdt)
    {:noreply, state}
  end

  # --- PRIVATE ---

  defp update_neighbors(crdt_pid) do
    neighbors = Node.list()
    Logger.debug("📡 Blackboard: Syncing with neighbors: #{inspect(neighbors)}")
    DeltaCrdt.set_neighbours(crdt_pid, neighbors)
  end
end
