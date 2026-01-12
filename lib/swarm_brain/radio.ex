defmodule SwarmBrain.Radio do
  @moduledoc """
  The Wilderness Link.
  Talks directly to the EMAX 2W module via UART.
  No TCP. No Handshakes. Just raw metal.
  """
  use GenServer
  require Logger
  alias Circuits.UART
  alias SwarmBrain.{Protocol, Pipeline}

  # --- API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def broadcast(observation) do
    GenServer.cast(__MODULE__, {:tx, observation})
  end

  # --- CALLBACKS ---

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, "/dev/ttyS0")
    speed = Keyword.get(opts, :speed, 420_000)

    {:ok, pid} = UART.start_link()

    # Configure for Raw Binary Mode
    # active: true means messages are sent to this process as {:circuits_uart, ...}

    # SOFT FAIL FIX: We try to open. If it fails, we stay alive as a dummy.
    case UART.open(pid, port, speed: speed, active: true) do
      :ok ->
        Logger.info("📡 RADIO ONLINE: Connected to #{port} at #{speed} baud.")
        {:ok, %{uart: pid, port: port, active: true}}

      {:error, reason} ->
        Logger.warning("⚠️ RADIO OFFLINE: Could not open #{port} (#{inspect(reason)}). Entering Simulation Mode.")
        # We return :ok anyway, so the Supervisor doesn't crash the app
        {:ok, %{uart: nil, port: port, active: false}}
    end
  end

  # RECEIVING (RX): Incoming Bytes from EMAX
  @impl true
  def handle_info({:circuits_uart, _port, binary_data}, state) do
    case Protocol.deserialize(binary_data) do
      %SwarmBrain.Observation{} = obs ->
        Logger.info("⚡️ RADIO RX: Received telegram ID:#{obs.id}")
        Pipeline.ingest_remote_signal(obs)
      :error ->
        :ok
    end
    {:noreply, state}
  end

  # SENDING (TX): Outgoing Observation
  @impl true
  def handle_cast({:tx, obs}, %{active: true} = state) do
    packet = Protocol.serialize(obs)
    UART.write(state.uart, packet)
    {:noreply, state}
  end

  # SENDING (TX): Dummy Mode (Radio hardware missing)
  def handle_cast({:tx, obs}, %{active: false} = state) do
    Logger.debug("👻 [SIMULATION] Radio TX would send: #{inspect(obs.id)}")
    # Here you could potentially write to a file to simulate transmission
    {:noreply, state}
  end
end
