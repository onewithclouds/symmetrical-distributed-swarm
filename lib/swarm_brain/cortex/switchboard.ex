defmodule SwarmBrain.Switchboard do
  use GenServer
  require Logger

  @doc "Starts the Switchboard with a default neural model."
  def start_link(default_model) do
    GenServer.start_link(__MODULE__, default_model, name: __MODULE__)
  end

  @impl true
  def init(model) do
    # WRITE: Initialize the atomic term
    :persistent_term.put(:active_cortex, model)
    Logger.info("Switchboard active. Cortex running on: #{inspect(model)}")
    {:ok, model}
  end

  # READ: No mailbox, direct memory access. Zero latency.
  # This prevents the bottleneck of thousands of drones asking the GenServer at once.
  def get_active_model do
    :persistent_term.get(:active_cortex)
  end

  # WRITE: Updates the term atomically.
  def swap_model(new_model) do
    GenServer.call(__MODULE__, {:swap, new_model})
  end

  @impl true
  def handle_call({:swap, new_model}, _from, _state) do
    # Atomic swap at the VM level.
    :persistent_term.put(:active_cortex, new_model)
    Logger.warning("Cortex Swapping to #{inspect(new_model)}")
    {:reply, :ok, new_model}
  end
end
