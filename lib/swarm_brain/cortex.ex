defmodule SwarmBrain.Cortex do
  @moduledoc """
  The High-Level Cognitive Processor.
  It coordinates specific neural modules (like ResNet) to analyze observations.
  """

  # --- THE CONTRACT ---
  # This makes Cortex a proper behaviour that other modules can implement.
  @callback analyze(image_tensor :: Nx.Tensor.t()) :: {:ok, map()} | {:error, term()}

  # --- CLIENT API ---

  def analyze(image_tensor) do
    # Dynamically find which brain module is active (configured in config.exs)
    # Defaulting to ResNet if not specified.
    brain_module = Application.get_env(:swarm_brain, :cortex_module, SwarmBrain.Cortex.ResNet)

    brain_module.analyze(image_tensor)
  end
end
