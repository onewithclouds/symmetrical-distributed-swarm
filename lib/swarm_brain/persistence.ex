defmodule SwarmBrain.Persistence do
  @moduledoc """
  The Black Box Recorder.
  Saves telemetry and detections to disk or upstream.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def log(data) do
    # Cast asynchronously so we don't block the Pipeline
    GenServer.cast(__MODULE__, {:log, data})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  # NEW: Handle Cluster Nodes
  def add_node_to_cluster(node_name) do
    Logger.info("🔗 [PERSISTENCE] Registering new node: #{inspect(node_name)}")
    # In the future, this updates the CRDT or local database
    :ok
  end

  @impl true
  def handle_cast({:log, data}, state) do
    # For now, just print to console.
    # Later: Write to SQLite or DETS.
    Logger.debug("💾 [PERSISTENCE] Saved: #{inspect(data)}")
    {:noreply, state}
  end
end
