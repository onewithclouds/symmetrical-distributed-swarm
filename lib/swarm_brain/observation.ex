defmodule SwarmBrain.Observation do
  @moduledoc """
  The Atomic Unit of Swarm Vision.
  Carries everything: The Image, The GPS, and The AI Analysis.
  """

  # Added :lat, :lon, :alt, :predictions to satisfy Location and ResNet
  defstruct [
    :id,
    :class,
    :confidence,
    :bbox,
    :timestamp,
    :image_binary,
    :lat, :lon, :alt,  # GPS Data
    :predictions       # Full raw output from AI
  ]

  @doc """
  Factory method to create a new blank observation from an image.
  """
  def new(image_binary) do
    %__MODULE__{
      id: UUID.uuid4(), # Requires elixr_uuid or just use system unique
      timestamp: DateTime.utc_now(),
      image_binary: image_binary
    }
  end

  # --- Payload Compression ---

  def prune_payload(obs, :emergency) do
    %{c: obs.class, b: obs.bbox, l: {obs.lat, obs.lon}}
  end

  def prune_payload(obs, :full) do
    # Strip heavy image binary before sending over network
    %{obs | image_binary: nil}
  end

  def prune_payload(obs), do: prune_payload(obs, :full)
end
