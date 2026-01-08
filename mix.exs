defmodule SwarmBrain.MixProject do
  use Mix.Project

  def project do
    [
      app: :swarm_brain,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # This ensures we don't accidentally compile inside the SSD if you didn't set the env vars
      build_path: System.get_env("MIX_BUILD_PATH") || "_build",
      deps_path: System.get_env("MIX_DEPS_PATH") || "deps"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :os_mon, :mnesia],
      mod: {SwarmBrain.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # --- 🧠 Neural Network Core ---
      {:bumblebee, "~> 0.6.0"},    # Pre-trained models (YOLOv8, ResNet, etc.)
      {:axon, "~> 0.7.0"},         # Neural Network framework
      {:nx, "~> 0.9.0"},           # Numerical Elixir (Tensors)

      # --- 🚀 Acceleration (The Engine) ---
      # EXLA is the compiler that makes Elixir fast for Math.
      # If you have NVIDIA: It uses CUDA.
      # If you have Intel/No GPU: It uses the CPU (still fast!).
      {:exla, "~> 0.9.0"},

      # --- 👁️ Vision & Utilities ---
      {:stb_image, "~> 0.6.0"},    # For decoding JPEGs from the DSLR
      {:req, "~> 0.5.0"},          # HTTP client (needed to download the YOLO model)
      {:kino, "~> 0.14.0"},        # Optional: Great for debugging visuals in Livebook

      # --- 🐝 Swarm & Distribution ---
      {:libcluster, "~> 3.4"},     # Automatic node discovery
      {:horde, "~> 0.9.0"},        # Distributed supervision
      {:delta_crdt, "~> 0.6.5"},   # Conflict-free Replicated Data Types (The Shared Brain)

      # --- 🚁 Flight Control ---
      # (Optional) If this node sends MAVLink commands directly
      # {:mave, "~> 0.1.0"},       # Or your preferred MAVLink library
    ]
  end
end
