defmodule SwarmBrain.Telemetry.Protocol do
  @moduledoc """
  The Vocabulary of the Void.
  Binary packing for high-interference environments.
  """

  # Header: 10101010 (Sync Byte)
  @sync_byte 0xAA

  # Command Definitions
  @cmd_delta_formation 0x01
  @cmd_line_formation  0x02
  @cmd_scatter         0xFF

  @doc """
  Compresses state into a 4-byte Heartbeat Vector.
  Format: <<SYNC, CMD, HEADING_BYTE, VELOCITY_BYTE>>
  """
  def encode_heartbeat(formation_type, heading_degrees, velocity_ms) do
    cmd = command_to_byte(formation_type)
    h_byte = compress_heading(heading_degrees)
    v_byte = compress_velocity(velocity_ms)

    <<@sync_byte, cmd, h_byte, v_byte>>
  end

  @doc """
  Decodes the roar of the static into actionable vector data.
  Returns: {:ok, %{formation: atom, heading: float, velocity: float}}
  """
  def decode(<<@sync_byte, cmd, h, v>>) do
    {:ok, %{
      formation: byte_to_command(cmd),
      heading: decompress_heading(h),
      velocity: decompress_velocity(v)
    }}
  end

  def decode(_noise), do: {:error, :invalid_packet}

  # --- Compression Logic (Lossy but Robust) ---

  # Map 0-360 degrees to 0-255
  defp compress_heading(degrees) do
    degrees
    |> Kernel.min(360.0)
    |> Kernel.max(0.0)
    |> (&(&1 * 255 / 360)).()
    |> round()
  end

  defp decompress_heading(byte), do: byte * 360.0 / 255.0

  # Map 0-25 m/s to 0-255 (Resolution: ~0.1 m/s)
  defp compress_velocity(ms) do
    ms
    |> Kernel.min(25.0) # Cap at 25m/s
    |> Kernel.max(0.0)
    |> (&(&1 * 10)).()
    |> round()
  end

  defp decompress_velocity(byte), do: byte / 10.0

  defp command_to_byte(:delta), do: @cmd_delta_formation
  defp command_to_byte(:line), do: @cmd_line_formation
  defp command_to_byte(_), do: @cmd_scatter

  defp byte_to_command(@cmd_delta_formation), do: :delta
  defp byte_to_command(@cmd_line_formation), do: :line
  defp byte_to_command(_), do: :scatter
end
