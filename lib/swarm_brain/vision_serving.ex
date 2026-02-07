# defmodule SwarmBrain.VisionServing do
#   @moduledoc """
#   The YOLOX-Small Engine.
#   Handles image normalization and raw tensor inference.
#   """
#   use GenServer
#   require Logger

#   def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

#   @impl true
#   def init(_opts) do
#     Logger.info("👁️ VisionServing: Initializing YOLOX-Small...")
#     model_path = "priv/yolox_s.onnx"

#     if File.exists?(model_path) do
#       model = Ortex.load(model_path)
#       Logger.info("👁️ VisionServing: Sight is Online.")
#       {:ok, %{model: model}}
#     else
#       Logger.error("❌ VisionServing: Brain file missing at #{model_path}")
#       {:stop, :missing_brain}
#     end
#   end

#   @impl true
#   def handle_call({:detect, image_binary}, _from, %{model: model} = state) do
#     # 1. DECODE: Use .shape instead of .height
#     {:ok, img} = StbImage.read_binary(image_binary)
#     {h, w, _c} = img.shape

#     # 2. PRE-PROCESS: Use NxImage (no underscore)
#     input_tensor =
#       Nx.from_binary(img.data, img.type)
#       |> Nx.reshape({h, w, 3})
#       |> NxImage.resize({640, 640})
#       |> Nx.transpose(axes: [2, 0, 1])
#       |> Nx.reshape({1, 3, 640, 640})
#       |> Nx.as_type(:f32)
#       |> Nx.divide(255.0)

#     # 3. INFERENCE
#     {output_tensor} = Ortex.run(model, input_tensor)

#     # Return a clean {:ok, tensor} tuple
#     {:reply, {:ok, output_tensor}, state}
#   end
# end
