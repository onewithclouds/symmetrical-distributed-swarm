defmodule SwarmBrain.Cortex do
  alias SwarmBrain.Observation

  # The Contract: "Any brain plugged into this socket must implement analyze/1"
  @callback analyze(%Observation{}) :: %Observation{}
end
