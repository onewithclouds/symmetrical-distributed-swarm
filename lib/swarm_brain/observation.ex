defmodule SwarmBrain.Observation do
  @moduledoc """
  The Standard Protocol.
  This struct is the "Signal" that flows through the Class A Amplifier.
  """
  defstruct [
    :id,              # Unique UUID for the memory
    :image_binary,    # The raw visual data
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
end
