defmodule SwarmBrain.Observation do
  @moduledoc """
  The Standard Protocol.
  This struct is the "Signal" that flows through the Class A Amplifier.
  Includes logic for "Heavy Packet" optimization (Payload Pruning).
  """
  defstruct [
    :id,              # Unique UUID for the memory
    :image_binary,    # The raw visual data (Heavy)
    :timestamp,       # When it was seen (UTC)
    :lat,             # GPS Latitude
    :lon,             # GPS Longitude
    :alt,             # GPS Altitude
    :predictions,     # The YOLO output (List of maps)
    :source_node      # Which device took the picture
  ]

  def new(image_binary, node_name \\ Node.self()) do
    %__MODULE__{
      id: :erlang.unique_integer([:positive, :monotonic]),
      image_binary: image_binary,
      timestamp: DateTime.utc_now(),
      source_node: node_name,
      predictions: []
    }
  end

  @doc """
  The Heavy Packet Optimization.
  Removes the heavy JPEG binary from the struct before network transmission.
  The receiving node will have the coordinates and label, but not the picture.
  If they need the picture, they must request it via ID (Lazy Loading - Future Feature).
  """
  def prune_payload(%__MODULE__{} = obs) do
    %{obs | image_binary: nil}
  end
end
