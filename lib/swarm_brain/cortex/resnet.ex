defmodule SwarmBrain.Cortex.ResNet do
  @behaviour SwarmBrain.Cortex.Model
  alias SwarmBrain.Vision.PreProcessor

  def analyze(%Nx.Tensor{} = raw_tensor) do
    # 1. JIT Compiled Pre-processing (Class A speed)
    input_batch = PreProcessor.prepare_resnet(raw_tensor)

    # 2. Inference (Mocked for now, but shape-compatible)
    # real_output = Axon.predict(model, input_batch)

    # Mock result
    %{
      label: "person",
      confidence: 0.98,
      bbox: [100, 100, 200, 400],
      tensor_shape: Nx.shape(input_batch) # Debug: Prove pre-processing worked
    }
  end

  # 2. OLD: Legacy Path (Resilient Fallback)
  # We remove the strict struct check to prevent compile errors if the struct is missing.
  # We just check for a map with the :image_binary key.
  def analyze(%{image_binary: bin}) when is_binary(bin) do
    tensor = Nx.from_binary(bin, {:u, 8})
             |> Nx.reshape({720, 1280, 3})
    analyze(tensor)
  end
end
