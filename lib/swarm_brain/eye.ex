defmodule SwarmBrain.Eye do
  @moduledoc """
  The Input Stage.
  Responsible for hardware interaction and signal conditioning.
  """
  require Logger
  alias SwarmBrain.Observation

  # 1. THE REVOLUTIONARY PIPELINE STEP
  # This function fits perfectly into a |> pipe.
  def capture(_opts \\ []) do
    # Emit a 'signal start' pulse for the dashboard
    :telemetry.execute([:swarm, :eye, :capture], %{count: 1})

    image_data = get_hardware_image()

    # Return the pure signal
    Observation.new(image_data)
  end

  # --- HARDWARE ABSTRACTION ---

  defp get_hardware_image do
    # In a real scenario, this detects if we are Linux/Mac/RPi
    # For now, we use the robust "Task" approach to prevent hanging.
    task = Task.async(fn ->
      # Simulating hardware latency
      Process.sleep(100)
      perform_shutter()
    end)

    case Task.yield(task, 2000) do
      {:ok, binary} -> binary
      nil ->
        Task.shutdown(task, :brutal_kill)
        Logger.error("⚠️ Camera Hardware Timeout! Returning static.")
        read_test_pattern()
    end
  end

  defp perform_shutter do
    cond do
      File.exists?("eye.jpg") -> File.read!("eye.jpg")
      true ->
        # Fallback to a 1x1 pixel black dot if nothing exists
        <<0::size(8)>>
    end
  end

  defp read_test_pattern, do: "PLACEHOLDER_BINARY"
end
