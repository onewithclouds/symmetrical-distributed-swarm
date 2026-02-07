defmodule SwarmBrain.Cortex.Model do
  @moduledoc """
  The Holy Contract.
  Every Cortex implementation (ResNet, YOLO, MobileNet) must obey this signature.
  """

  # The callback defines the shape of the "thought"
  # It accepts a Tensor (fast path) or a Map (legacy path)
  # It must return a prediction map.
  @callback analyze(Nx.Tensor.t() | map()) :: %{
    label: String.t(),
    confidence: float(),
    bbox: list(integer())
  }
end
