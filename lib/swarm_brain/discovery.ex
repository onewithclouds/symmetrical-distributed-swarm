defmodule SwarmBrain.Discovery do
  @moduledoc """
  The Civilian Link.
  Manages WiFi/Erlang Distribution connections.
  If this fails, the Pipeline automatically falls back to Radio.
  """
  use GenServer
  require Logger
  alias SwarmBrain.Persistence

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
      if node_name != Node.self() do
        Node.connect(node_name)
      end
    end)

    # Check who is actually alive for logging
    connected = Node.list()
    if connected != [] do
      Logger.debug("🌐 WiFi Mesh Active: #{inspect(connected)}")
      # Sync databases if we have a connection
      Enum.each(connected, &Persistence.add_node_to_cluster/1)
    end

    Process.send_after(self(), :connect, @interval)
    {:noreply, state}
  end

  defp list_target_nodes do
    # Symmetrical List of known IP addresses
    [:"brain@192.168.1.147", :"brain@192.168.1.243"]
  end
end
