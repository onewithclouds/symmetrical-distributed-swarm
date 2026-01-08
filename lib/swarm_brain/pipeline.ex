defmodule SwarmBrain.Pipeline do
  @moduledoc """
  The Main Circuit Board.
  It connects the Eye (Input) to the Cortex (Processing) using Process Groups.
  """
  require Logger
  alias SwarmBrain.{Eye, Location, Cortex, Observation, Persistence}

  # ... (run_scout_sequence and run_local_sequence remain the same) ...

  def run_scout_sequence do
    Eye.capture()
    |> Location.stamp()
    |> broadcast_to_brain()
  end

  def run_local_sequence do
    Eye.capture()
    |> Location.stamp()
    |> Cortex.analyze()
    |> persist_memory()
  end

  # ... (broadcast_to_brain remains the same) ...
  defp broadcast_to_brain(%Observation{} = obs) do
    # "pg" is Erlang's Process Group. We ask: "Who is in the 'brains' group?"
    brains = :pg.get_members(:brains)

    case brains do
      [] ->
        Logger.warning("📡 No Brains detected in range! Dropping packet.")
        {:error, :no_brain}

      [target | _] ->
        Logger.info("📡 Beaming signal to brain: #{inspect(target)}")
        send(target, {:remote_process, obs})
        {:ok, :sent}
    end
  end

  # --- 4. PERSISTENCE (UPDATED) ---

  def persist_memory(%Observation{predictions: [top|_]} = obs) do
    # 1. Write to Mnesia (Disk)
    Persistence.save(obs)

    Logger.info("💾 Memory Persisted: #{top.label} (ID: #{obs.id})")

    # 2. Notify the Watchman (Visual/CSV logging)
    send(SwarmBrain.Watchman, {:observation_stored, obs})
    obs
  end

  # Handle case where no predictions exist
  def persist_memory(obs), do: obs
end
