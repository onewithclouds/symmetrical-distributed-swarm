defmodule SwarmBrain.Cortex.ResNet do
  # 1. Adopt the Behaviour (The Law)
  @behaviour SwarmBrain.Cortex

  alias SwarmBrain.Observation
  require Logger

  # 2. THIS IS YOUR ORIGINAL CODE (SAFE AND SOUND)
  def analyze(%Observation{image_binary: bin} = obs) do
    :telemetry.execute([:swarm, :cortex, :think], %{count: 1})
    Logger.info("🧠 Cortex (ResNet) is thinking...")

    # ... (All your original logic for StbImage and Nx.Serving stays here) ...
    tensor =
      bin
      |> StbImage.read_binary!()
      |> StbImage.to_nx()

    %{predictions: preds} = Nx.Serving.batched_run(SwarmBrain.VisionServing, tensor)

    %{obs | predictions: preds}
  end
end
