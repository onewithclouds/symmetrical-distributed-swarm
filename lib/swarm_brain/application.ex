defmodule SwarmBrain.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # 1. Initialize Mnesia Schema/Table ON DISK
    SwarmBrain.Persistence.setup()

    # 2. Join the "Airwaves" (WiFi Group)
    :pg.start_link()

    children = [
      SwarmBrain.Discovery,

      # 📡 NEW: The Wilderness Link (UART/LoRa)
      # We pass the serial port address (adjust "/dev/ttyS0" to your hardware)
      {SwarmBrain.Radio, [port: "/dev/ttyS0", speed: 420_000]},

      # The Antenna listens for internal Erlang messages
      SwarmBrain.Antenna,

      # The Vision Serving (The Neural Network Engine)
      {Nx.Serving, serving: vision_serving(), name: SwarmBrain.VisionServing},

      SwarmBrain.Watchman
    ]

    opts = [strategy: :one_for_one, name: SwarmBrain.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # --- VISION ENGINE SETUP ---
  defp vision_serving do
    local_path = Path.join([File.cwd!(), "models", "yolov8n"])

    if File.exists?(local_path) do
      Logger.info("🧠 Loading Local Model from: #{local_path}")
      {:ok, model} = Bumblebee.load_model({:local, local_path})
      {:ok, featurizer} = Bumblebee.load_featurizer({:local, local_path})
      Bumblebee.Vision.image_classification(model, featurizer)
    else
      Logger.warning("⚠️ Local model missing. Downloading ResNet-50...")
      {:ok, model} = Bumblebee.load_model({:hf, "microsoft/resnet-50"})
      {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "microsoft/resnet-50"})
      Bumblebee.Vision.image_classification(model, featurizer)
    end
  end
end
