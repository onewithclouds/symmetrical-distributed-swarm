defmodule SwarmBrain.Antenna do
  @moduledoc """
  The Hardware Interface for RF Communication (LoRa/ELRS).
  Formerly 'Radio'.
  """
  use GenServer
  require Logger
  # alias Circuits.UART # Uncomment when running on real hardware

  @topic "radio:telemetry"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("📡 Antenna Listening on UART...")
    # Mocking UART connection for development
    # In production: UART.open(...)
    {:ok, %{port: nil, rssi: -60}}
  end

  @impl true
  def handle_info({:circuits_uart, _port, data}, state) do
    # 1. Strip noise
    clean_data = String.trim(data)

    # 2. Broadcast to the Swarm (Formation, Pipeline, etc.)
    # We do NOT call Pipeline directly anymore.
    Phoenix.PubSub.broadcast(SwarmBrain.PubSub, @topic, {:telemetry_packet, clean_data, state.rssi})

    {:noreply, state}
  end

  # Catch-all for when we are running without real hardware
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
