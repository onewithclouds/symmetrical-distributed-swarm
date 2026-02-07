defmodule SwarmBrain.Radio do
  use GenServer
  require Logger
  alias Circuits.UART

  # The Void listens on this topic
  @topic "radio:telemetry"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, uart_pid} = UART.start_link()

    # Initialize UART (Assuming connection to EMAX/ELRS module)
    # Active: true means messages are sent as Erlang messages, not polling.
    UART.open(uart_pid, "/dev/ttyAMA0", speed: 420_000, active: true)

    # Configure generic UART framing (Packet mode) if applicable
    # UART.configure(uart_pid, framing: {UART.Framing.Line, separator: "\n"})

    {:ok, %{uart: uart_pid, rssi: -60}}
  end

  # --- The "Async-Ack" Implementation ---

  # Standard Data Packet
  def handle_info({:circuits_uart, _port, data}, state) do
    # 1. Parse RSSI from hardware (Implementation depends on specific ELRS/Hardware module)
    # For simulation, we pretend the hardware injects RSSI at end of frame
    {clean_data, current_rssi} = extract_rssi(data)

    # 2. BROADCAST IMMEDIATELY. Do not call Pipeline. Do not block.
    # The system is now event-driven.
    Phoenix.PubSub.broadcast(SwarmBrain.PubSub, @topic, {:telemetry_packet, clean_data, current_rssi})

    {:noreply, %{state | rssi: current_rssi}}
  end

  def handle_info({:uart_error, _port, reason}, state) do
    Logger.error("Radio interference detected: #{inspect(reason)}")
    {:noreply, state}
  end

  # --- Helpers ---

  # Mockup of RSSI extraction. In real ELRS CRSF protocol, this is in the LinkStatistics frame.
  defp extract_rssi(data) do
    # If using Crossfire protocol, we would parse the LinkStats frame here.
    # Returning dummy data for the skeleton.
    {data, -50}
  end
end
