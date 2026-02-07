import Config

# We plug the module into the Cortex socket
config :swarm_brain, :cortex_module, SwarmBrain.Cortex.Yolo

# The Nixie-HP Webcam (VGA)
config :swarm_brain, :vision,
  width: 640,
  height: 480,
  framerate: 30

# 1. Set the Default Backend to EXLA (XLA)
# This forces Nx to use the compiled C++ backend (CPU or GPU)
config :nx, :default_backend, EXLA.Backend

# 2. Configure the Target
# If you are on the INTEL laptop without an NVIDIA card:
config :exla, :default_client, :host

# ⚠️ IF you manage to get an eGPU or NVIDIA card working later:
# config :exla, :default_client, :cuda
# config :exla, :clients,
#   cuda: [platform: :cuda]

# 3. CRDT Sync Interval
config :delta_crdt, :sync_interval, 50 # Sync fast (50ms) for flight data

# --- [NEW] HIVE DISCOVERY PROTOCOL ---
config :libcluster,
  topologies: [
    swarm_gossip: [
      # UDP Multicast: No central server needed.
      # Works on local WiFi/Mesh networks immediately.
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "230.1.1.251",
        # Set to true if multicast is blocked on your router,
        # but usually false is better for true mesh.
        broadcast_only: false
      ]
    ]
  ]

# Hardware Interface
# Set to "/dev/ttyUSB0" or "/dev/ttyTHS1" when on the drone.
# Set to nil to force Simulation Mode on Laptop.
config :swarm_brain, :fc_port, nil

# RL Actor Configuration
config :swarm_brain, :actor,
  model_path: "priv/actor_policy.axon",
  input_shape: 11
