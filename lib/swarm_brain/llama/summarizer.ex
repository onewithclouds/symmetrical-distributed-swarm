defmodule SwarmBrain.Llama.Summarizer do
  @moduledoc "Translates vision detections into tactical language prompts."

  def generate_prompt(detections, previous_context \\ []) do
    # Detections is a list of %{label: "person", bbox: [...]}

    events = Enum.map_join(detections, "\n", fn d ->
      "- Visual Contact: #{d.label} (Conf: #{Float.round(d.confidence, 2)})"
    end)

    """
    [MISSION LOG]
    Time: #{DateTime.utc_now()}
    Context: #{Enum.join(previous_context, "; ")}

    CURRENT SENSORS:
    #{events}

    TACTICAL ASSESSMENT:
    Based on the above, identify threats and suggest a formation adjustment.
    """
  end
end
