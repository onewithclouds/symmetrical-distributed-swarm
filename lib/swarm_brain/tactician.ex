defmodule SwarmBrain.Tactician do
  use GenServer
  require Logger

  # This module is the high-level manager for the AI Tactician (Llama.cpp).
  # It wraps the Rust NIFs and holds the model state.

  # --- CLIENT API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def think(prompt) do
    GenServer.call(__MODULE__, {:think, prompt}, 60_000) # 60s timeout for thinking
  end

  # --- SERVER CALLBACKS ---

  @impl true
  def init(_opts) do
    # 1. Define the model path
    model_path = Application.app_dir(:swarm_brain, "priv/tactician.gguf")

    # 2. Check if model exists before crashing
    if not File.exists?(model_path) do
      Logger.error("❌ Model not found at: #{model_path}")
      {:stop, :model_missing}
    else
      # 3. Load the Model (via Rust NIF)
      # We assume the NIF loading happens here or is managed by the Native module.
      # If your NIF load function is `SwarmBrain.Tactician.Native.load_model/3`:
      # SwarmBrain.Tactician.Native.load_model(model_path, 2048, -1)

      # 4. THE FIX IS HERE:
      # We log the success instead of returning the string as the function result.
      Logger.info("🧠 Tactician Core online. Memory mapped: #{model_path}")

      # 5. The State
      # We return the tuple {:ok, state}. The state is just a map for now.
      {:ok, %{model_path: model_path, context_size: 2048}}
    end
  end

  @impl true
  def handle_call({:think, prompt}, _from, state) do
    # This forwards the prompt to the Rust NIF
    # response = SwarmBrain.Tactician.Native.think(prompt)

    # Placeholder response until NIF is fully connected in your logic:
    response = "Tactician hears you: #{prompt}"

    {:reply, response, state}
  end
end
