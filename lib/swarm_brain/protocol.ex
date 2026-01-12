defmodule SwarmBrain.Protocol do
  @moduledoc """
  The Compressor.
  Converts high-level thoughts (Structs) into low-level telegrams (Bytes).
  Protocol Format (14 Bytes Total):
  [HEADER(1)][ID(4)][LAT(4)][LON(4)][CLASS(1)]
  """

  alias SwarmBrain.Observation
  @header 0xAA

  # --- SERIALIZE (Struct -> Bytes) ---
  def serialize(%Observation{} = obs) do
    # 1. Map labels to simple integers (0=Unknown, 1=Human, 2=Tank)
    class_id = map_label_to_byte(List.first(obs.predictions))

    # 2. Pack the bytes
    # We use float-32 (Little Endian) to save space.
    # Accuracy is ~1.5m, sufficient for swarm.
    <<
      @header,
      obs.id :: integer-32-little,
      obs.lat :: float-32-little,
      obs.lon :: float-32-little,
      class_id :: integer-8
    >>
  end

  # --- DESERIALIZE (Bytes -> Struct) ---
  def deserialize(<<@header, id::integer-32-little, lat::float-32-little, lon::float-32-little, class_id::integer-8, _rest::binary>>) do
    label = map_byte_to_label(class_id)

    %Observation{
      id: id,
      lat: lat,
      lon: lon,
      timestamp: DateTime.utc_now(),
      source_node: :remote_radio,
      predictions: [%{label: label, score: 1.0}] # We assume radio signals are confident
    }
  end

  # Fallback for garbage noise
  def deserialize(_), do: :error

  # --- MAPPING HELPERS ---
  defp map_label_to_byte(%{label: "person"}), do: 1
  defp map_label_to_byte(%{label: "car"}), do: 2
  defp map_label_to_byte(%{label: "tank"}), do: 3
  defp map_label_to_byte(_), do: 0 # Unknown

  defp map_byte_to_label(1), do: "person"
  defp map_byte_to_label(2), do: "car"
  defp map_byte_to_label(3), do: "tank"
  defp map_byte_to_label(_), do: "unknown"
end
