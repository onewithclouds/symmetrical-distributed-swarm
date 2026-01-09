defmodule SwarmBrain.Persistence do
  @moduledoc """
  The Long-Term Memory.
  Handles Mnesia database setup, reading, writing, and clustering.
  """
  require Logger
  alias SwarmBrain.Observation

  @table :sightings

  # --- SETUP ---

def setup do
    # 1. STOP Mnesia first.
    # (It was auto-started by Mix in RAM mode, preventing Schema creation)
    :mnesia.stop()

    # 2. Create the Schema on Disk
    # This creates the physical folder structure.
    case :mnesia.create_schema([node()]) do
      :ok ->
        Logger.info("💾 Mnesia Schema created successfully.")
      {:error, {_, {:already_exists, _}}} ->
        Logger.info("💾 Mnesia Schema already exists.")
      error ->
        Logger.error("❌ Mnesia Schema Creation Failed: #{inspect(error)}")
    end

    # 3. START Mnesia (Now in Disk Mode)
    :mnesia.start()

    # 4. Create the Table
    case :mnesia.create_table(@table, [
      attributes: [:id, :label, :score, :lat, :lon, :timestamp, :node],
      disc_copies: [node()]
    ]) do
      {:atomic, :ok} -> Logger.info("💾 Mnesia Table created on Disk.")
      {:aborted, {:already_exists, _}} -> Logger.info("💾 Mnesia Table loaded from Disk.")
      error -> Logger.error("❌ Mnesia Table Error: #{inspect(error)}")
    end

    :mnesia.wait_for_tables([@table], 5000)
  end

  # --- CLUSTERING ( The Magic ) ---

# --- CLUSTERING (The Healer) ---

  def add_node_to_cluster(target_node) do
    Logger.info("🧠 Swarm Link: Syncing memory with #{target_node}...")

    # 1. Connect Mnesia networking
    :mnesia.change_config(:extra_db_nodes, [target_node])

    # 2. CONVERGENCE: Ensure BOTH nodes have the table.
    # It doesn't matter who has it first; Mnesia will handle the copy.

    # A. Ask Remote Node to store a copy (Push)
    case :rpc.call(target_node, :mnesia, :add_table_copy, [@table, target_node, :disc_copies]) do
      {:atomic, :ok} -> Logger.info("✅ Remote: Memory replicated to #{target_node}")
      {:aborted, {:already_exists, _}} -> :ok # Silent success
      other -> Logger.warning("⚠️ Remote Sync: #{inspect(other)}")
    end

    # B. Ask Local Node to store a copy (Pull)
    case :mnesia.add_table_copy(@table, Node.self(), :disc_copies) do
      {:atomic, :ok} -> Logger.info("✅ Local: Memory replicated from Swarm")
      {:aborted, {:already_exists, _}} -> :ok # Silent success
      other -> Logger.warning("⚠️ Local Sync: #{inspect(other)}")
    end
  end

  # --- READ / WRITE ---

  def save(%Observation{} = obs) do
    # Extract the top prediction (if any)
    {label, score} = case obs.predictions do
      [top | _] -> {top.label, top.score}
      [] -> {"unknown", 0.0}
    end

    # Define the record tuple matching the table attributes
    record = {@table, obs.id, label, score, obs.lat, obs.lon, obs.timestamp, obs.source_node}

    # Write transaction
    write_op = fn -> :mnesia.write(record) end

    case :mnesia.transaction(write_op) do
      {:atomic, :ok} -> :ok
      err -> Logger.error("Failed to save memory: #{inspect(err)}")
    end
  end

  def get_recent_sightings(limit \\ 10) do
    # Simple query to get all keys, mostly for debugging
    :mnesia.dirty_all_keys(@table)
    |> Enum.take(limit)
    |> Enum.map(fn key -> :mnesia.dirty_read(@table, key) end)
  end
end
