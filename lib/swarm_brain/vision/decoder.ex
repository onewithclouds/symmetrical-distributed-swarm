defmodule SwarmBrain.Vision.Decoder do
  import Nx.Defn

  @moduledoc "Vectorized decoding logic for neural outputs."

  defn decode_vectorized(predictions, threshold) do
    # 1. Mask: 1.0 if score > threshold, else 0.0
    scores = predictions[[.., 4]]
    mask = Nx.greater(scores, threshold)

    cx = predictions[[.., 0]]
    cy = predictions[[.., 1]]
    w  = predictions[[.., 2]]
    h  = predictions[[.., 3]]

    # 2. Calculate coordinates
    x1 = cx - (w / 2)
    y1 = cy - (h / 2)
    x2 = cx + (w / 2)
    y2 = cy + (h / 2)

    # 3. Stack results: [x1, y1, x2, y2, score]
    boxes = Nx.stack([x1, y1, x2, y2, scores], axis: 1)

    # 4. Zero-out invalid boxes (Soft Filtering)
    # Instead of removing rows (which is illegal in defn), we set them to 0.
    zero_tensor = Nx.broadcast(0.0, boxes)

    # Expand mask to match box shape for selection
    # mask is [N], boxes is [N, 5]. We need to broadcast mask.
    mask_expanded = Nx.broadcast(Nx.new_axis(mask, -1), boxes)

    Nx.select(mask_expanded, boxes, zero_tensor)
  end
end
