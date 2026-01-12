defmodule SwarmBrain.Persistence do
  @moduledoc """
  The Long-Term Memory.
  Implements "Genesis Boot" to handle Split-Brain scenarios automatically.
  Includes "Ghost in the Shell" Black Box writing for crash resilience.
  """
  require Logger
  alias SwarmBrain.Observation

  @table :sightings
  # Hardcoded peer list for discovery (Symmetrical - both have same list)
  @peers [:"brain@192.168.1.147", :"brain@192.168.1.243"]
  @blackbox_log "blackbox.log"

  # --- SETUP (The Genesis Protocol) ---

  def setup do
    # 1. Stop Mnesia to ensure clean state
    :mnesia.stop()

    # 2. Check for Life in the Universe
    # We filter out ourselves and ping the others.
    others = @peers -- [node()]
    living_peers = Enum.filter(others, fn n -> Node.ping(n) == :pong end)

    if Enum.empty?(living_peers) do
      # 👑 CASE A: Solitary Node (Leader)
      # No one else is here. I trust my own disk.
      Logger.info("👑 No active swarm detected. Loading local memory from disk.")
      :mnesia.create_schema([node()])
      :mnesia.start()
    else
      # 🤝 CASE B: Joining Existing Swarm (Follower)
      # The swarm is alive. My local schema might be stale/conflicting.
      # "Zen Mode": I empty my cup so it can be filled.
      Logger.info("🐝 Active swarm detected #{inspect(living_peers)}. Wiping local schema to join.")

      # WIPE SELF (This replaces the risky recursive delete)
      :mnesia.delete_schema([node()])
      :mnesia.start()

      # Connect to the swarm database
      :mnesia.change_config(:extra_db_nodes, living_peers)

      # Ensure we have the table definition
      case :mnesia.wait_for_tables([@table], 5000) do
         :ok -> :ok
         _ ->
            # If table doesn't exist yet in swarm, we might need to copy it
            :ok
      end
    end

    init_table()
  end

  defp init_table do
    # Create the table if it doesn't exist (On Disk)
    case :mnesia.create_table(@table, [attributes: [:uuid, :data], disc_copies: [node()]]) do
      {:atomic, :ok} -> Logger.info("✅ Memory table created.")
      {:aborted, {:already_exists, _}} -> Logger.info("✅ Memory table loaded.")
      other -> Logger.error("❌ Mnesia Table Init: #{inspect(other)}")
    end

    :mnesia.wait_for_tables([@table], 5000)
  end

  # --- CLUSTERING (The Healer) ---

  def add_node_to_cluster(target_node) do
    # This now handles the "Idempotent" log cleanup you asked for
    :mnesia.change_config(:extra_db_nodes, [target_node])

    # A. Push (Ask them to copy)
    case :rpc.call(target_node, :mnesia, :add_table_copy, [@table, target_node, :disc_copies]) do
      {:atomic, :ok} -> Logger.info("✅ Remote: Memory replicated to #{target_node}")
      {:aborted, {:already_exists, _}} -> :ok # Silent success
      other -> Logger.warning("⚠️ Remote Sync: #{inspect(other)}")
    end

    # B. Pull (Ensure I have copy)
    case :mnesia.add_table_copy(@table, Node.self(), :disc_copies) do
      {:atomic, :ok} -> Logger.info("✅ Local: Memory replicated from Swarm")
      {:aborted, {:already_exists, _}} -> :ok # Silent success
      other -> Logger.warning("⚠️ Local Sync: #{inspect(other)}")
    end
  end

  # --- SAVE & RETRIEVE (With Black Box) ---

  def save(%Observation{} = obs) do
    {label, score} = case obs.predictions do
      [top | _] -> {top.label, top.score}
      [] -> {"unknown", 0.0}
    end

    # 1. GHOST IN THE SHELL: Secure Write
    # Write to raw log immediately to survive power loss
    secure_log_entry = "#{DateTime.to_string(obs.timestamp)},#{label},#{score},#{obs.lat},#{obs.lon},#{obs.source_node}\n"
    secure_write(secure_log_entry)

    # 2. Polite Write (Mnesia)
    trans = fn ->
      :mnesia.write({@table, obs.id, obs})
    end

    case :mnesia.transaction(trans) do
      {:atomic, :ok} -> :ok
      other -> Logger.error("Failed to persist memory: #{inspect(other)}")
    end
  end

  def get_recent_sightings(limit \\ 10) do
    # A simple dirty read for the dashboard
    # In production, use :mnesia.select for better querying
    keys = :mnesia.dirty_all_keys(@table)

    keys
    |> Enum.take(-limit) # Take last N
    |> Enum.map(fn key ->
      [{_, _, obs}] = :mnesia.dirty_read(@table, key)
      obs
    end)
  end

  # --- PRIVATE: THE BLACK BOX WRITER ---

  defp secure_write(data) do
    # Force the OS to write to physical silicon IMMEDIATELY.
    # It slows down the system, but ensures the memory survives the crash.
    # O_SYNC / :sync flag bypasses the OS buffer cache.
    case File.write(@blackbox_log, data, [:append, :sync]) do
      :ok -> :ok
      {:error, reason} -> Logger.error("🔥 BLACKBOX FAILURE: #{inspect(reason)}")
    end
  end
end
