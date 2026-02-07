defmodule SwarmBrain.Sensor.Fusion do
  @moduledoc """
  The Inner Ear & Fovea.
  A GenServer that:
  1. Owns the 'Target' memory (ETS) - The Pre-Amp.
  2. Receives asynchronous vision updates via message passing.
  """
  use GenServer
  require Logger

  # Dedicated Memory for Visual Targets
  @table :fusion_targets
  @key :current_target

  # --- API ---
  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # Fast Read for the Pilot (Non-blocking)
  def get_visual_target do
    case :ets.lookup(@table, @key) do
      [{@key, target}] -> target
      [] -> nil
    end
  end

  # --- SERVER ---
  def init(_) do
    Logger.info("👂 Fusion: Online. Stabilizing Sensory Inputs.")
    # Create the table (Owned by this process, protected write, public read)
    :ets.new(@table, [:set, :named_table, :protected, read_concurrency: true])
    {:ok, %{}}
  end

  # The message from Blackboard comes here
  def handle_info({:visual_contact, detections}, state) do
    # 1. Filter Logic (Simple 'best' selection for now)
    best = List.first(detections)

    if best do
      # Write to fast memory
      :ets.insert(@table, {@key, best})
    end

    {:noreply, state}
  end

  # Catch-all for other messages to prevent crashes
  def handle_info(_msg, state), do: {:noreply, state}
end
