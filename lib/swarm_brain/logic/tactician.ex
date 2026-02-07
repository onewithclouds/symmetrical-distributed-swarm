defmodule SwarmBrain.Logic.Tactician do
  @moduledoc """
  The Strategist.
  Pure logic module that decides WHICH target to pursue based on priority weights.
  Decoupled from Sensor Fusion and State Management.
  """
  import Nx.Defn

  # Constants (COCO Class IDs)
  @person_id 0
  @watch_id 19

  # Weights (The "Value" of a target)
  @weight_person 100.0
  @weight_watch 50.0

  @doc """
  Input: A tensor of detections [[class_id, confidence, x, y], ...]
  Output: The index of the best target.
  """
  defn select_primary_target_index(detections) do
    # 1. Extract Columns
    class_ids = detections[[.., 0]]
    confidences = detections[[.., 1]]

    # 2. Assign Tactical Weights (Vectorized Strategy)
    # If Class == Person, Score = 100. Else if Watch, Score = 50. Else 0.
    weights =
      Nx.select(class_ids == @person_id, @weight_person,
        Nx.select(class_ids == @watch_id, @weight_watch, 0.0)
      )

    # 3. Calculate Final Score (Weight * Confidence)
    final_scores = weights * confidences

    # 4. Argmax to find the winner
    Nx.argmax(final_scores)
  end

  @doc """
  Input: The box [x1, y1, x2, y2]
  Output: A normalized center point [-1.0 to 1.0] for the Pilot.
  """
  defn normalize_target_vector(bbox) do
    # Image center (Assuming 640x480 resolution)
    w = 640.0
    h = 480.0

    x1 = bbox[0]
    y1 = bbox[1]
    x2 = bbox[2]
    y2 = bbox[3]

    cx = (x1 + x2) / 2.0
    cy = (y1 + y2) / 2.0

    # Normalize to -1.0 (Left/Top) to 1.0 (Right/Bottom)
    norm_x = (cx - (w / 2.0)) / (w / 2.0)
    norm_y = (cy - (h / 2.0)) / (h / 2.0)

    Nx.stack([norm_x, norm_y])
  end
end
