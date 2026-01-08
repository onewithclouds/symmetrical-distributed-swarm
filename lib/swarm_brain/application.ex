defmodule SwarmBrain.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # 1. Initialize Mnesia Schema/Table ON DISK
    SwarmBrain.Persistence.setup()

    # 2. Join the "Airwaves"
    :pg.start_link()

    children = [
      SwarmBrain.Discovery,

      # Using ResNet because YOLO download is failing (User Request)
      {Nx.Serving, serving: vision_serving(), name: SwarmBrain.VisionServing},

      SwarmBrain.Watchman,
      {Task, fn -> join_brain_cluster() end}
    ]

    opts = [strategy: :one_for_one, name: SwarmBrain.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ... (join_brain_cluster, listen_for_signals, vision_serving remain same) ...
  defp join_brain_cluster do
    :pg.join(:brains, self())
    listen_for_signals()
  end

  defp listen_for_signals do
    receive do
      {:remote_process, observation} ->
        Logger.info("⚡️ Received remote signal from #{observation.source_node}")
        observation
        |> SwarmBrain.Cortex.analyze()
        |> SwarmBrain.Pipeline.persist_memory()
        listen_for_signals()
    end
  end

  defp vision_serving do
    model_path = Path.join([File.cwd!(), "models", "yolov8n"])
    Logger.info("🧠 Loading Local Model (ResNet) from: #{model_path}")
    {:ok, model} = Bumblebee.load_model({:local, model_path})
    {:ok, featurizer} = Bumblebee.load_featurizer({:local, model_path})
    Bumblebee.Vision.image_classification(model, featurizer)
  end
end
