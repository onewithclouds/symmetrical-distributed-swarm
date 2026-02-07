defmodule SwarmBrain.Vision.NMS do
  use Rustler, otp_app: :swarm_brain, crate: "swarm_brain_nms"

  def nms(_boxes, _iou_threshold), do: :erlang.nif_error(:nif_not_loaded)
end
