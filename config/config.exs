import Config

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