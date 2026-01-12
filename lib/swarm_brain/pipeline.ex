defmodule SwarmBrain.Pipeline do
  @moduledoc """
  The Main Circuit Board.
  Connects Inputs -> Cortex -> Persistence.
  Now features "Dual-Mode Switching" (WiFi vs Radio).
  """
  require Logger
  alias SwarmBrain.{Eye, Location, Observation, Persistence, Radio}

  @cortex Application.compile_env(:swarm_brain, :cortex_module)

  # --- PUBLIC API ---

  def run_local_sequence do
    Eye.capture()
    |> Location.stamp()
    |> process_signal()
  end

  def ingest_remote_signal(observation) do
    process_signal(observation)
  end

  def run_scout_sequence do
    Eye.capture()
    |> Location.stamp()
    |> broadcast_to_brain()
  end

  # --- INTERNAL CIRCUIT ---

  # 1. DOUBLE-THINK FIX: Skip analysis if predictions exist
  defp process_signal(%Observation{predictions: [_|_]} = obs) do
    persist_memory(obs)
  end

  # 2. FRESH DATA: Analyze it
  defp process_signal(obs) do
    obs
    |> @cortex.analyze()
    |> persist_memory()
  end

  def persist_memory(obs) do
    Persistence.save(obs)
    send(SwarmBrain.Watchman, {:observation_stored, obs})
    obs
  end

  # --- THE DUAL-MODE SWITCH ---
  defp broadcast_to_brain(%Observation{} = obs) do
    # Check for High-Bandwidth Peers (WiFi)
    # Node.list() returns connected Erlang nodes.
    case Node.list() do
      [] ->
        # 🌑 WILDERNESS MODE (No WiFi)
        # Send a compressed telegram via EMAX 2W
        Logger.info("🌑 No WiFi peers. Switching to RADIO TELEGRAM.")
        Radio.broadcast(obs)

        # We also process locally since we couldn't offload it
        process_signal(obs)

      peers ->
        # ☀️ CIVILIAN MODE (WiFi Present)
        # Send the full struct with image via TCP
        target = Enum.random(peers)
        Logger.info("☀️ WiFi peers found. Offloading task to #{inspect(target)}.")

        # Prune heavy image if needed (optional optimization)
        payload = Observation.prune_payload(obs)
        send({SwarmBrain.Antenna, target}, {:remote_process, payload})
    end
  end
end
