defmodule SwarmBrain.Watchman do
  use GenServer
  require Logger

  @log_file "brain_observations.csv"

  # --- Client API ---

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    # 1. Cluster Monitoring
    :net_kernel.monitor_nodes(true)

    # 2. Subscribe to Mnesia (Legacy/Redundant backup)
    :mnesia.subscribe({:table, :sightings, :detailed})

    # 3. Setup CSV
    if !File.exists?(@log_file), do: File.write!(@log_file, "timestamp,event,details\n")

    # REMOVED: schedule_vision_check() - We are now Passive listeners!

    Logger.info("🕵️ Watchman is active. Waiting for Pipeline signals.")
    {:ok, %{nodes: Node.list()}}
  end

  # --- Handling the Swarm Events (Node Up/Down) ---

  @impl true
  def handle_info({:nodeup, node}, state) do
    log_event("CONNECTION", "Swarm became one with node: #{node}")
    IO.puts("✨ [SWARM] Node connected: #{node}. Symmetrical state syncing...")
    {:noreply, %{state | nodes: [node | state.nodes]}}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    log_event("DISCONNECT", "Lost connection to node: #{node}")
    IO.puts("🚨 [SWARM] Node lost: #{node}. Entering autonomous mode.")
    {:noreply, %{state | nodes: List.delete(state.nodes, node)}}
  end

  # --- NEW: Handling the Pipeline Signal ---
  # This receives the struct from SwarmBrain.Pipeline
  @impl true
  def handle_info({:observation_stored, obs}, state) do
    # 1. Unpack the signal
    %{predictions: preds, lat: lat, lon: lon, source_node: node} = obs

    # 2. Format the output
    top_label = case preds do
      [top | _] -> "#{top.label} (#{Float.round(top.score * 100, 1)}%)"
      [] -> "Unknown Object"
    end

    details = "Detected #{top_label} at [#{lat}, #{lon}] by #{node}"

    # 3. Log to CSV and Screen
    log_event("SIGHTING", details)
    IO.puts("🔔 [WATCHMAN] #{details}")

    {:noreply, state}
  end

  # Fallback for other Mnesia events
  @impl true
  def handle_info({:mnesia_table_event, _}, state), do: {:noreply, state}

  # Catch-all
  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private Helpers ---

  defp log_event(event_type, details) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    clean_details = String.replace(details, "\"", "'")
    entry = "#{timestamp},#{event_type},\"#{clean_details}\"\n"
    File.write!(@log_file, entry, [:append])
  end
end
