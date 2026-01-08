defmodule SwarmBrain.Cortex do
  alias SwarmBrain.Observation
  require Logger

  # THE PIPELINE STEP
  def analyze(%Observation{image_binary: bin} = obs) do
    :telemetry.execute([:swarm, :cortex, :think], %{count: 1})
    Logger.info("🧠 Cortex is thinking...")

    # 1. Convert Binary to Tensor
    tensor =
      bin
      |> StbImage.read_binary!()
      |> StbImage.to_nx()

    # 2. Run the Serving (The Neural Network)
    # We call the named process defined in Application.ex
    %{predictions: preds} = Nx.Serving.batched_run(SwarmBrain.VisionServing, tensor)

    # 3. Return the annotated signal
    %{obs | predictions: preds}
  end
end
