defmodule SwarmBrain.Actor.Network do
  @moduledoc "The RL Policy Network definition."

  # 4 (Fused) + 200 (Optical Flow) + 3 (Intent) = 207
  @input_size 207
  @output_size 4

  def build_model do
    Axon.input("state", shape: {nil, @input_size})
    |> Axon.dense(128, activation: :tanh)
    |> Axon.dense(64, activation: :tanh)
    |> Axon.dense(@output_size, activation: :tanh)
  end

  # [FIXED] Replaced deprecated Axon.init/4 with Axon.build/2 pattern
  def init_random_params do
    model = build_model()
    # Template: {BatchSize, Features}
    template = Nx.template({1, @input_size}, :f32)

    # Axon.build returns {init_fn, predict_fn}
    {init_fn, _} = Axon.build(model, compiler: EXLA)

    # Initialize with default state
    init_fn.(template, %{})
  end

  def predict(model_state, input) do
    model = build_model()
    # Using EXLA compiler for inference
    Axon.predict(model, model_state, input, compiler: EXLA)
  end
end
