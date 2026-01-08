{
  description = "The Unified Swarm: One Environment to Rule Them All";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        
        # 1. Core BEAM Stack
        beamStack = with pkgs; [ elixir_1_18 erlang_27 rebar3 ];

        # 2. Combined capabilities
        scoutTools = with pkgs; [ 
          python3 
          mavproxy # Note: top-level pkgs, not python3Packages
          python3Packages.pymavlink 
        ];
        
        brainTools = with pkgs; [
          libgphoto2 opencv4 pkg-config cmake gcc libusb1 ffmpeg-full
        ];

      in {
        devShells.default = pkgs.mkShell {
          name = "swarm-unified";
          buildInputs = beamStack ++ scoutTools ++ brainTools;

          shellHook = ''
            export MIX_ENV=dev
            # Identity based on machine name
            export NODE_NAME="$(hostname)"
            
            # Force CPU mode for resilience on Intel hardware
            export EXLA_TARGET=host
            export XLA_TARGET=cpu

            # Symmetric Path Logic: Keeps artifacts in the local project dir
            export MIX_BUILD_PATH="$PWD/_build"
            export MIX_DEPS_PATH="$PWD/deps"

            echo "🐝 Unified Swarm Environment Loaded"
            echo "   - Hardware: $(hostname)"
            echo "   - Capabilities: Scout (MAVLink) + Brain (Vision)"
          '';
        };
      }
    );
}