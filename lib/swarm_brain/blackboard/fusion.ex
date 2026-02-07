defmodule SwarmBrain.Blackboard.Fusion do
  @moduledoc """
  The Vectorized Tactical Processor.
  Uses EXLA/Nx to fuse sensor data from multiple drones in O(1) time.
  """
  import Nx.Defn

  # Constants for Classification
  @person_id 0
  @watch_id 19 # Example ID from COCO

  @doc """
  Accepts a batch of detections: [[class_id, confidence, x, y], ...]
  Returns the index of the highest priority target.
  """
  defn select_primary_target_index(detections) do
    # 1. Extract Columns
    class_ids = detections[[.., 0]]
    confidences = detections[[.., 1]]

    # 2. Assign Tactical Weights (Vectorized)
    # Person (0) = 100.0, Watch (19) = 50.0, Others = 0.0
    weights =
      Nx.select(class_ids == @person_id, 100.0,
        Nx.select(class_ids == @watch_id, 50.0, 0.0)
      )

    # 3. Calculate Final Score (Weight * Confidence)
    final_scores = weights * confidences

    # 4. Argmax to find the winner
    Nx.argmax(final_scores)
  end
end
