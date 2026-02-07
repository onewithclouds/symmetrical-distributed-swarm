defmodule SwarmBrain.Blackboard do
  @moduledoc "The Distributed Hive Mind."
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

    # 1. Start CRDT
    {:ok, crdt_pid} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: @sync_interval)

    # 2. Monitor Nodes
    :net_kernel.monitor_nodes(true)
    update_neighbors(crdt_pid)

    # 3. Return PROPER Struct
    {:ok, %__MODULE__{crdt: crdt_pid}}
  end

  # --- API ---

  def update_vision(detections, _meta) do
    GenServer.cast(__MODULE__, {:update_local_vision, detections})
  end

  # --- CALLBACKS ---

  def handle_cast({:update_local_vision, detections}, state) do
    # 1. Hive Sync
    best = List.first(detections) || %{label: "none"}
    DeltaCrdt.put(state.crdt, :vision_summary, %{node: Node.self(), label: best[:label]})

    # 2. Local Reflex
    send(SwarmBrain.Sensor.Fusion, {:visual_contact, detections})

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
    # [FIX] DeltaCrdt requires a LIST, not a MapSet.
    # We explicitly convert Node.list() (which is a list) just to be safe,
    # but more importantly, we ensure we don't pass a MapSet if we were doing set math.
    neighbors = Node.list()

    Logger.debug("📡 Blackboard: Syncing with neighbors: #{inspect(neighbors)}")
    DeltaCrdt.set_neighbours(crdt_pid, neighbors)
  end
end
