defmodule SwarmBrain.Vision.Yolo.PostProcessor do
  @moduledoc "Vectorized NMS for Predator Vision."
  import Nx.Defn

  # Tunable Constraints (Static for XLA optimization)
  @max_detections 20

  @doc """
  Performs Non-Maximum Suppression.
  Arguments must be explicit tensors, not keyword lists.
  """
  defn non_max_suppression(boxes, scores, iou_threshold \\ 0.45) do
    # 1. Sort scores descending
    sorted_indices = Nx.argsort(scores, direction: :desc)
    sorted_boxes = Nx.take(boxes, sorted_indices)

    # 2. Initialize mask (1 = keep)
    initial_mask = Nx.broadcast(1, scores)

    # 3. Static Loop (XLA requires constant bounds)
    # We check the top 20 candidates.
    {final_mask, _, _, _} =
      while {mask = initial_mask, boxes = sorted_boxes, scores, iou_threshold}, i <- 0..(@max_detections - 1) do
        current_box = boxes[i]
        ious = calculate_iou(current_box, boxes)

        # Kill box if IoU > threshold AND it has a lower rank
        suppress =
          ious
          |> Nx.greater(iou_threshold)
          |> Nx.logical_and(Nx.iota(Nx.shape(mask)) |> Nx.greater(i))

        new_mask = Nx.select(suppress, 0, mask)

        {new_mask, boxes, scores, iou_threshold}
      end

    # 4. Return Top K Indices and the Mask
    top_k_indices = sorted_indices[0..(@max_detections - 1)]
    top_k_mask = final_mask[0..(@max_detections - 1)]

    {top_k_indices, top_k_mask}
  end

  defnp calculate_iou(box_a, boxes_b) do
    inter_x1 = Nx.max(box_a[0], boxes_b[[.., 0]])
    inter_y1 = Nx.max(box_a[1], boxes_b[[.., 1]])
    inter_x2 = Nx.min(box_a[2], boxes_b[[.., 2]])
    inter_y2 = Nx.min(box_a[3], boxes_b[[.., 3]])

    inter_w = Nx.max(0.0, inter_x2 - inter_x1)
    inter_h = Nx.max(0.0, inter_y2 - inter_y1)
    inter_area = inter_w * inter_h

    area_a = (box_a[2] - box_a[0]) * (box_a[3] - box_a[1])
    area_b = (boxes_b[[.., 2]] - boxes_b[[.., 0]]) * (boxes_b[[.., 3]] - boxes_b[[.., 1]])

    union_area = area_a + area_b - inter_area
    inter_area / (union_area + 1.0e-6)
  end
end
