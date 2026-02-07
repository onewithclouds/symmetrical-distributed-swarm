defmodule SwarmBrain.Cortex.Yolo do
  @behaviour SwarmBrain.Cortex.Model
  require Logger
 alias SwarmBrain.Vision.PreProcessor

  # [NEW] Import Defn for JIT Compilation
  import Nx.Defn

  @model_path "priv/yolox_s_int8.onnx"

  def init do
    path = Application.app_dir(:swarm_brain, @model_path)
    Logger.info("👁️ Loading Predator Vision: #{path}")
    model = Ortex.load(path)
    :persistent_term.put(:yolo_model, model)
  end

  def analyze(%Nx.Tensor{} = raw_image) do
    model = :persistent_term.get(:yolo_model)

    # 1. Prepare (EXLA)
    input_tensor = PreProcessor.prepare_yolo(raw_image)

    # 2. Run Inference (Ortex)
    {output_ref} = Ortex.run(model, input_tensor)

    # 3. Transfer Memory (Ortex -> EXLA)
    predictions = Nx.backend_transfer(output_ref, EXLA.Backend)

    # 4. [NEW] JIT Post-Processing
    # We offload the heavy math to the compiled kernel.
    # Returns a tuple of tensors: {score, box, class_id}
    {best_score_t, box_t, class_id_t} = fast_post_process(predictions)

    # 5. [ADAPTATION] The Logic Bridge
    # We must pull the values out of the Tensors (GPU/CPU) back to Elixir (Host)
    confidence = Nx.to_number(best_score_t)

    # Threshold Check (Preserving your logic)
    if confidence > 0.4 do
      class_id = Nx.to_number(class_id_t)

      # Box comes out as [x1, y1, x2, y2] from the fast kernel
      bbox = Nx.to_flat_list(box_t)

      %{
        label: get_coco_label(class_id),
        confidence: confidence,
        bbox: bbox,
        count: 1 # Since we use ArgMax, we focus on the single best target
      }
    else
      # Nothing valid found
      %{label: "none", confidence: 0.0, bbox: [], count: 0}
    end
  end

  # --- THE NEW FAST ENGINE (JIT COMPILED) ---

  defn fast_post_process(predictions) do
    # 1. Remove batch dim
    preds = predictions[0]

    # 2. Slice columns
    # 0..3: [cx, cy, w, h] (Center Format)
    # 4: Objectness
    # 5..84: Class Scores
    box_center = preds[[.., 0..3]]
    obj_conf = preds[[.., 4]]
    class_scores = preds[[.., 5..84]]

    # 3. Vectorized Math (Objectness * Best Class Score)
    max_class_score = Nx.reduce_max(class_scores, axes: [1])
    final_scores = obj_conf * max_class_score

    # 4. Find the single best candidate (Argmax)
    # This replaces the slow Sort/NMS for single-target tracking
    best_idx = Nx.argmax(final_scores)
    best_score = final_scores[best_idx]

    # 5. Extract and Transform Box
    # Yolo outputs [cx, cy, w, h]. We need [x1, y1, x2, y2].
    raw_box = box_center[best_idx]

    cx = raw_box[0]
    cy = raw_box[1]
    w = raw_box[2]
    h = raw_box[3]

    # Coordinate Math inside the JIT (Very Fast)
    x1 = cx - (w / 2.0)
    y1 = cy - (h / 2.0)
    x2 = cx + (w / 2.0)
    y2 = cy + (h / 2.0)

    final_box = Nx.stack([x1, y1, x2, y2])

    # 6. Extract Class ID
    best_class_scores = class_scores[best_idx]
    class_id = Nx.argmax(best_class_scores)

    # Return tuple of tensors
    {best_score, final_box, class_id}
  end

  # --- LEGACY MAPPING (Preserved) ---

  defp get_coco_label(id) do
    case id do
      0 -> "person"
      1 -> "bicycle"
      2 -> "car"
      3 -> "motorcycle"
      4 -> "airplane"
      5 -> "bus"
      6 -> "train"
      7 -> "truck"
      8 -> "boat"
      9 -> "traffic light"
      10 -> "fire hydrant"
      11 -> "stop sign"
      12 -> "parking meter"
      13 -> "bench"
      14 -> "bird"
      15 -> "cat"
      16 -> "dog"
      17 -> "horse"
      18 -> "sheep"
      19 -> "cow"
      20 -> "elephant"
      21 -> "bear"
      22 -> "zebra"
      23 -> "giraffe"
      24 -> "backpack"
      25 -> "umbrella"
      26 -> "handbag"
      27 -> "tie"
      28 -> "suitcase"
      29 -> "frisbee"
      30 -> "skis"
      31 -> "snowboard"
      32 -> "sports ball"
      33 -> "kite"
      34 -> "baseball bat"
      35 -> "baseball glove"
      36 -> "skateboard"
      37 -> "surfboard"
      38 -> "tennis racket"
      39 -> "bottle"
      40 -> "wine glass"
      41 -> "cup"
      42 -> "fork"
      43 -> "knife"
      44 -> "spoon"
      45 -> "bowl"
      46 -> "banana"
      47 -> "apple"
      48 -> "sandwich"
      49 -> "orange"
      50 -> "broccoli"
      51 -> "carrot"
      52 -> "hot dog"
      53 -> "pizza"
      54 -> "donut"
      55 -> "cake"
      56 -> "chair"
      57 -> "couch"
      58 -> "potted plant"
      59 -> "bed"
      60 -> "dining table"
      61 -> "toilet"
      62 -> "tv"
      63 -> "laptop"
      64 -> "mouse"
      65 -> "remote"
      66 -> "keyboard"
      67 -> "cell phone"
      68 -> "microwave"
      69 -> "oven"
      70 -> "toaster"
      71 -> "sink"
      72 -> "refrigerator"
      73 -> "book"
      74 -> "clock"
      75 -> "vase"
      76 -> "scissors"
      77 -> "teddy bear"
      78 -> "hair drier"
      79 -> "toothbrush"
      _ -> "unknown"
    end
  end
end
