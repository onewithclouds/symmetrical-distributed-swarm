defmodule SwarmBrain.Vision.Retina do
  use GenServer
  require Logger
  alias SwarmBrain.Vision.Native
  alias SwarmBrain.Cortex

  # Resolution Configuration
  @width 640
  @height 480

  # Sensitivity (Higher = less sensitive to small movements)
  @sad_threshold 500_000

  # Keyframe Sync: Every 60 frames (approx 2s at 30fps)
  @keyframe_tick 60

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("👁 Retina: Online. Initializing Rust Gatekeeper.")

    # Initialize the Rust NIF Resource
    {:ok, resource} = Native.init_retina(@width, @height, @sad_threshold)

    {:ok, %{
      resource: resource,
      frame_count: 0
    }}
  end

  # This function is called by your Camera/Sensor loop
  def process_frame(frame_binary) do
    GenServer.cast(__MODULE__, {:frame, frame_binary})
  end

  @impl true
  def handle_cast({:frame, frame_bin}, state) do
    # 1. Keyframe Sync Logic
    is_keyframe = rem(state.frame_count, @keyframe_tick) == 0

    if is_keyframe do
       # SYNC: Force full Cortex analysis to correct temporal drift
       # Logger.debug("👁 Retina: Keyframe Sync")
       trigger_full_inference(frame_bin)
       {:noreply, %{state | frame_count: state.frame_count + 1}}
    else
       # 2. GATED PERCEPTION (Rust NIF)
       case Native.detect_change(state.resource, frame_bin) do
         :no_change ->
            # Silence... efficient silence.
            {:noreply, %{state | frame_count: state.frame_count + 1}}

         {:change, {x, y, w, h}} ->
            # 3. ROI CROP (Evolutionary Efficiency)
            # Logger.debug("👁 Retina: Movement detected at {#{x}, #{y}}")

            # Using Evision (OpenCV) as requested for fast slicing
            # We assume frame_bin is raw grayscale u8
            frame_bin
            |> Evision.Mat.from_binary(@height, @width, :u8, 1)
            |> Evision.Mat.roi({x, y, w, h})
            # Convert ROI back to Tensor for the Brain
            |> to_nx_tensor()
            |> Cortex.analyze()

            {:noreply, %{state | frame_count: state.frame_count + 1}}
       end
    end
  end

  # Helper to bridge Evision Mat -> Nx Tensor
  defp to_nx_tensor(evision_mat) do
    binary_data = Evision.Mat.to_binary(evision_mat)
    {h, w, _c} = Evision.Mat.shape(evision_mat)

    binary_data
    |> Nx.from_binary(:u8)
    |> Nx.reshape({h, w, 1})
  end

  defp trigger_full_inference(bin) do
    bin
    |> Nx.from_binary(:u8)
    |> Nx.reshape({@height, @width, 1})
    |> Cortex.analyze()
  end
end
