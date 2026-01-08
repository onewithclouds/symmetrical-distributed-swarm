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

  def add_node_to_cluster(target_node) do
    # This function runs when Discovery finds a new friend.
    # It copies our database to them.

    Logger.info("🧠 Syncing Memory with #{target_node}...")

    # 1. Connect Mnesia Config
    :mnesia.change_config(:extra_db_nodes, [target_node])

    # 2. Tell the other node to store a copy on RAM (or Disk)
    # We use RPC to tell the *remote* node to add a table copy.
    rpc_result = :rpc.call(target_node, :mnesia, :add_table_copy, [@table, target_node, :disc_copies])

    case rpc_result do
      {:atomic, :ok} -> Logger.info("✅ Memory Replicated to #{target_node}")
      {:aborted, {:already_exists, _}} -> Logger.debug("✅ Memory already exists on #{target_node}")
      other -> Logger.warning("⚠️ Memory Sync Warning: #{inspect(other)}")
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
