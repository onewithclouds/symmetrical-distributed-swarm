defmodule SwarmBrain.Vision.PreProcessor do
  @moduledoc "Universal optics that adapt to any camera resolution."
  import Nx.Defn

  @target_size 640

  # --- PART 1: THE ARCHITECT (CPU) ---
  # Calculates the geometry.
  # This is a normal Elixir function, not JIT-compiled.
  def prepare_yolo(tensor) do
    # Extract concrete integers from the tensor struct
    {h, w, _c} = tensor.shape

    # Calculate Scale (Standard Elixir Math)
    scale = max(@target_size / h, @target_size / w)

    # Calculate target dimensions (Must be Integers)
    new_h = round(h * scale)
    new_w = round(w * scale)

    # Pass these integers as CONSTANTS (opts) to the JIT compiler
    apply_yolo_optics(tensor, size: {new_h, new_w}, crop_size: {@target_size, @target_size})
  end

  # --- PART 2: THE BUILDER (GPU/EXLA) ---
  # This is the JIT-compiled kernel.
  # It takes 'opts' which are baked into the compiled graph as constants.
  defn apply_yolo_optics(tensor, opts \\ []) do
    opts = keyword!(opts, [:size, :crop_size])
    target_size = opts[:size]
    crop_size = opts[:crop_size]

    tensor
    |> Nx.as_type(:f32)

    # Resize using the static integers passed from Part 1
    |> NxImage.resize(target_size, method: :bilinear)

    # Center crop
    |> NxImage.center_crop(crop_size)

    # Polish
    |> Nx.reverse(axes: [2])
    |> Nx.transpose(axes: [2, 0, 1])
    |> Nx.new_axis(0)
  end

  # ResNet remains standard
  defn prepare_resnet(tensor) do
    tensor
    |> Nx.as_type(:f32)
    |> Nx.divide(255.0)
    |> NxImage.resize({224, 224}, method: :bilinear)
    |> Nx.transpose(axes: [2, 0, 1])
    |> Nx.new_axis(0)
    |> normalize()
  end

  defnp normalize(tensor) do
    mean = Nx.tensor([0.485, 0.456, 0.406], type: :f32) |> Nx.reshape({3, 1, 1})
    std = Nx.tensor([0.229, 0.224, 0.225], type: :f32) |> Nx.reshape({3, 1, 1})
    (tensor - mean) / std
  end
end
