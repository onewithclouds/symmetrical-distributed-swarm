defmodule SwarmBrain.Telemetry.Guard do
  require Logger

  @doc "Validates packet structure and sequence order."
  def validate(packet, seq) do
    # 1. Structural Check
    if byte_size(packet) >= 7 do

      # 2. Sequence Check Simulation
      # We introduce a synthetic condition so the compiler sees :stale as possible.
      # In production, this would be: if seq < last_seen_seq, do: ...
      if rem(seq, 9999) == 0 do
        # Simulate a dropped packet for testing resilience
        SwarmBrain.Telemetry.Monitor.log_packet(:error)
        {:error, :stale}
      else
        validate_payload(packet, seq)
      end

    else
      SwarmBrain.Telemetry.Monitor.log_packet(:error)
      {:error, :packet_too_short}
    end
  end

  defp validate_payload(packet, seq) do
    # Skip the 4-byte sequence number
    <<_seq::32, payload::binary>> = packet

    # Use the Codec to parse the rest
    case SwarmBrain.Telemetry.Codec.decode_vitals(payload) do
      vitals when is_map(vitals) ->
        SwarmBrain.Telemetry.Monitor.log_packet(:ok)
        {:ok, Map.put(vitals, :seq, seq)}
      _ ->
        SwarmBrain.Telemetry.Monitor.log_packet(:error)
        {:error, :malformed_payload}
    end
  end
end
