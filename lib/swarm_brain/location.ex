defmodule SwarmBrain.Location do
  alias SwarmBrain.Observation

  def stamp(%Observation{} = obs) do
    # In the future: call mavlink or gpsd here
    {lat, lon, alt} = get_current_gps()

    %{obs | lat: lat, lon: lon, alt: alt}
  end

  defp get_current_gps do
    # Placeholder: Lviv High Castle
    {49.8481, 24.0397, 350.0}
  end
end
