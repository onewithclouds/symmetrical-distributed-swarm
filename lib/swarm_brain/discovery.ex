defmodule SwarmBrain.Discovery do
  use GenServer
  require Logger
  alias SwarmBrain.Persistence

  # ⏱️ Heartbeat Interval
  @interval 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :connect)
    {:ok, %{nodes: list_target_nodes()}}
  end

  @impl true
  def handle_info(:connect, state) do
    Enum.each(state.nodes, fn node_name ->
      connect_to_node(node_name)
    end)

    # Optional: Don't log status every 5s if it's spammy,
    # but for Class A monitoring, it's nice.
    # log_cluster_status()

    Process.send_after(self(), :connect, @interval)
    {:noreply, state}
  end

  defp connect_to_node(node_name) do
    if node_name != Node.self() do
      case Node.connect(node_name) do
        true ->
          # ✨ NEW: When we connect, try to sync memory!
          Persistence.add_node_to_cluster(node_name)
          :ok
        false ->
          # Silent fail is fine, we'll try again in 5s
          :ok
        :ignored ->
          :ok
      end
    end
  end

  defp list_target_nodes do
    # You can update this list or use a dynamic scan
    [:"brain@192.168.1.147", :"brain@192.168.1.243"]
  end

  # defp log_cluster_status, do: :ok
end
