defmodule SwarmBrain.Hardware.Spine do
  @moduledoc """
  The Spinal Cord.
  Translates 'Intent' (RL Output) into 'MSP' (Flight Controller Protocol).
  Implements the "Reflex Arc" - safe clamping and mapping of signals.
  """
  use GenServer
  require Logger

  # MSP Command IDs
  @msp_set_raw_rc 200
  @msp_ident 100
  # @msp_attitude 108 (Uncomment when we implement full telemetry parsing)

  # PWM Constants (Standard RC)
  @pwm_min 1000
  @pwm_max 2000
  @pwm_mid 1500

  defstruct [:uart_pid, :mode, :last_attitude]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # API
  def get_imu_state, do: GenServer.call(__MODULE__, :get_attitude)

  # The Reflex Trigger: Called by Tracker 30 times a second
  def send_controls(r, p, y, t), do: GenServer.cast(__MODULE__, {:command, {r, p, y, t}})

  def init(_opts) do
    uart_dev = Application.get_env(:swarm_brain, :fc_port)

    # Simple Hardware Check
    if uart_dev && File.exists?(uart_dev) do
      Logger.info("🔌 Spine: Connecting to Nervous System (FC) on #{uart_dev}")
      {:ok, pid} = Circuits.UART.start_link()
      Circuits.UART.open(pid, uart_dev, speed: 115200, active: true)

      # Handshake
      request_ident(pid)

      {:ok, %__MODULE__{mode: :hardware, uart_pid: pid, last_attitude: %{roll: 0.0, pitch: 0.0, yaw: 0.0}}}
    else
      Logger.warning("👻 Spine: No Flight Controller detected. Running in GHOST MODE.")
      {:ok, %__MODULE__{mode: :ghost, uart_pid: nil, last_attitude: %{roll: 0.0, pitch: 0.0, yaw: 0.0}}}
    end
  end

  # --- REFLEX LOOP ---

  def handle_cast({:command, {r, p, y, t}}, %{mode: :hardware} = state) do
    # 1. Map RL Intent (-1.0 to 1.0) to PWM (1000 to 2000)
    payload = encode_rc_payload(r, p, y, t)

    # 2. Send to Nervous System (FC)
    Circuits.UART.write(state.uart_pid, pack_msp(@msp_set_raw_rc, payload))

    {:noreply, state}
  end

  def handle_cast({:command, _}, %{mode: :ghost} = state) do
    # In Ghost Mode, we do nothing. The Tracker logs the output.
    {:noreply, state}
  end

  # --- INCOMING SENSORY DATA ---

  # [FIX] Prefix unused 'data' with underscore to silence warning
  def handle_info({:circuits_uart, _, _data}, state) do
    # Placeholder: Future telemetry parsing goes here.
    {:noreply, state}
  end

  # --- MSP PROTOCOL ---

  defp request_ident(pid), do: Circuits.UART.write(pid, pack_msp(@msp_ident, <<>>))

  defp pack_msp(cmd_id, payload) do
    size = byte_size(payload)
    checksum = bitwise_xor_checksum(size, cmd_id, payload)
    << "$", "M", "<", size, cmd_id, payload::binary, checksum >>
  end

  defp bitwise_xor_checksum(size, cmd, payload) do
    initial = Bitwise.bxor(size, cmd)
    for <<byte <- payload>>, reduce: initial do
      acc -> Bitwise.bxor(acc, byte)
    end
  end

  # The "Reflex" Mapper
  defp encode_rc_payload(r, p, y, t) do
    <<
      map_to_pwm(r)::little-16, # Roll
      map_to_pwm(p)::little-16, # Pitch
      map_to_pwm(t)::little-16, # Throttle
      map_to_pwm(y)::little-16, # Yaw
      @pwm_mid::little-16,      # Aux1 (Arm?) - [FIX] Use Attribute
      @pwm_min::little-16,      # Aux2          [FIX] Use Attribute
      @pwm_min::little-16,      # Aux3
      @pwm_min::little-16       # Aux4
    >>
  end

  defp map_to_pwm(val) do
    # Clamp safety
    clamped = max(-1.0, min(val, 1.0))

    # [FIX] Dynamic calculation using Attributes instead of hardcoded numbers
    # Slope = (2000 - 1000) / 2 = 500
    slope = (@pwm_max - @pwm_min) / 2.0
    intercept = @pwm_mid

    round((clamped * slope) + intercept)
  end

  def handle_call(:get_attitude, _from, state) do
    {:reply, state.last_attitude, state}
  end
end
