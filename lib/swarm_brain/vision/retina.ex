  defmodule SwarmBrain.Vision.Retina do
  use GenServer
  require Logger
  alias SwarmBrain.Vision.Native
  alias SwarmBrain.Vision.Server
  alias SwarmBrain.Cortex

# Resolution Configuration
  # We read the config block defined in config.exs under :swarm_brain, :vision
  # No default provided. If config.exs is broken, this returns nil or raises an error depending on strictness.
  @vision_config Application.compile_env!(:swarm_brain, :vision)
  @width @vision_config[:width]
  @height @vision_config[:height]

  # Keyframe Sync: Every 60 frames (approx 2s at 30fps)
  @keyframe_tick 60

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("👁 Retina: Online. Linking to Iron Lung...")

    # [FIX 1] Lazy Initialization
    # We do not call Native.init_retina(). We wait to grab the shared
    # resource from the Server's persistent_term.
    {:ok, %{
      resource: nil,
      frame_count: 0
    }}
  end

  # This function is called by your Camera/Sensor loop
  def process_frame(frame_binary) do
    GenServer.cast(__MODULE__, {:frame, frame_binary})
  end

  @impl true
  def handle_cast({:frame, frame_bin}, state) do
    # 1. Lazy Resource Fetch
    resource = state.resource || Server.get_resource()

    if is_nil(resource) do
      # If the Iron Lung isn't ready, we can't see. Drop frame.
      {:noreply, state}
    else
      # 2. Keyframe Sync Logic
      is_keyframe = rem(state.frame_count, @keyframe_tick) == 0

      if is_keyframe do
         # SYNC: Force full Cortex analysis to correct temporal drift
         trigger_full_inference(frame_bin)
         {:noreply, %{state | resource: resource, frame_count: state.frame_count + 1}}
      else
         # 3. GATED PERCEPTION (Rust NIF)
         # [FIX 2] Arity 1: Rust checks its internal Triple Buffer.
         # [FIX 3] Return Type: We get a raw tuple, not a tagged atom.
         case Native.detect_change(resource) do
           {0, 0, 0, 0} ->
              # Silence... efficient silence.
              {:noreply, %{state | resource: resource, frame_count: state.frame_count + 1}}

           {x, y, w, h} ->
              # 4. ROI CROP
              # Logger.debug("👁 Retina: Movement detected at {#{x}, #{y}}")

              # We use the 'frame_bin' passed in for the crop source
              frame_bin
              |> Evision.Mat.from_binary(@height, @width, :u8, 1)
              |> Evision.Mat.roi({x, y, w, h})
              |> to_nx_tensor()
              |> Cortex.analyze()

              {:noreply, %{state | resource: resource, frame_count: state.frame_count + 1}}
         end
      end
    end
  end

  # Helper to bridge Evision Mat -> Nx Tensor
  defp to_nx_tensor(evision_mat) do
    binary_data = Evision.Mat.to_binary(evision_mat)
    {h, w, _c} = Evision.Mat.shape(evision_mat)

    # Assuming YOLO expects RGB, but Evision might be grayscale here.
    # Adjust channels if necessary.
    Nx.from_binary(binary_data, :u8)
    |> Nx.reshape({h, w, 1})
  end

  defp trigger_full_inference(frame_bin) do
    # Convert full frame to Tensor and fire
    Nx.from_binary(frame_bin, :u8)
    |> Nx.reshape({@height, @width, 3}) # Assuming RGB input
    |> Cortex.analyze()
  end
end
