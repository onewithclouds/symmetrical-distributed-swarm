defmodule SwarmBrain.Antenna do
  @moduledoc """
  The Receiver.
  It listens for incoming thoughts from other nodes and passes them to the Pipeline.
  """
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Join the "brains" group so we can hear the signals
    :pg.join(:brains, self())
    Logger.info("📡 Antenna is listening for remote signals...")
    {:ok, state}
  end

  # The Handle Info callback is the standard OTP way to receive messages
  @impl true
  def handle_info({:remote_process, observation}, state) do
    Logger.info("⚡️ Antenna picked up signal from #{observation.source_node}")

    # Pass it to the Unified Pipeline
    # We use Task.start so the Antenna is immediately ready for the next signal
    Task.start(fn ->
      SwarmBrain.Pipeline.ingest_remote_signal(observation)
    end)

    {:noreply, state}
  end
end
