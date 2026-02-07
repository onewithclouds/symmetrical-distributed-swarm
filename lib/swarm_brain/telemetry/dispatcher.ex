defmodule SwarmBrain.Telemetry.Dispatcher do
  @moduledoc "Parallel decoding with Circuit Breaker and Sequence ordering."
  require Logger

  # Circuit Breaker Limit: 5000 pending messages
  @max_queue_len 5000

  def dispatch_batch(packet_list) do
    # 1. Circuit Breaker (Strategic Mitigation)
    if message_queue_len() > @max_queue_len do
      Logger.warning("Circuit Breaker Tripped: Shedding load.")
      :ignore
    else
      process_batch(packet_list)
    end
  end

  defp process_batch(packet_list) do
    packet_list
    |> Task.async_stream(fn packet ->
      # 2. Lamport Timestamp Check (Low-Level Mitigation)
      # Assuming first 32 bits are the sequence number
      # NOTE: Ensure your packet format actually starts with 32-bit seq,
      # otherwise this pattern match will crash.
      case packet do
        <<seq::32, _rest::binary>> ->
          # Only process if valid (Guard handles the check)
          case SwarmBrain.Telemetry.Guard.validate(packet, seq) do
            {:ok, vitals} ->
              Phoenix.PubSub.broadcast(SwarmBrain.PubSub, "swarm:vitals", {:update, vitals})
            {:error, :stale} ->
              :ignore # Drop out-of-order packet
            {:error, _} ->
              :ignore
          end
        _ ->
          # Handle packets too short to contain a seq number
          :ignore
      end
    end, max_concurrency: System.schedulers_online(), ordered: false)
    |> Stream.run()
  end

  defp message_queue_len, do: Process.info(self(), :message_queue_len) |> elem(1)
end
