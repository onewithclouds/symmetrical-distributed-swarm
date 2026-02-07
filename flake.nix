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

        # ======================================================================
        # ⚠️  ARCHITECT'S NOTE TO FUTURE TRAVELERS (AI OR HUMAN)  ⚠️
        # ======================================================================
        # THIS FLAKE IMPLEMENTS "CLANG SUPREMACY".
        #
        # We enforce the use of `clangStdenv` and explicitly link `libclang` to 
        # reconcile the Rust and Elixir compilation toolchains. 
        #
        # DO NOT introduce GCC or standard `stdenv` overrides without understanding 
        # the delicate treaty between Rustler (NIFs) and the BEAM.
        #
        # Any change here must preserve:
        # 1. LIBCLANG_PATH export.
        # 2. BINDGEN_EXTRA_CLANG_ARGS with -isystem includes.
        # 3. The exclusion of conflicting C standard libraries.
        # ======================================================================
        
        # 1. Core BEAM Stack
        beamStack = with pkgs; [ elixir_1_18 erlang_27 rebar3 ];

        # 2. Scout & Archiver Tools
        scoutTools = with pkgs; [ 
          python3 
          python3Packages.tree-sitter
          # We provide the raw grammars here. The Python script will 
          # build the binaries from these sources.
          tree-sitter-grammars.tree-sitter-elixir
          tree-sitter-grammars.tree-sitter-rust
          
          python3Packages.pymavlink 
          python3Packages.onnx 
          python3Packages.onnxruntime 
          python3Packages.numpy 
          python3Packages.sympy

          python3Packages.sentence-transformers
        ];
        
        # 3. Brain Tools (Aligned with Clang)
        brainTools = with pkgs; [
          libgphoto2 
          opencv4 
          pkg-config 
          cmake 
          libusb1 
          ffmpeg-full 
          gnumake
          libclang.lib
          cargo 
          rustc
        ];

      in {
        # CRITICAL: We override the standard environment with Clang.
        devShells.default = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
          name = "swarm-unified";
          
          nativeBuildInputs = [ 
            pkgs.libclang.lib 
            pkgs.pkg-config 
            pkgs.cmake 
          ]; 
          
          buildInputs = beamStack ++ scoutTools ++ brainTools;

          shellHook = ''
            export MIX_ENV=dev
            export NODE_NAME="$(hostname)"
            export EXLA_TARGET=host
            export XLA_TARGET=cpu
            export MIX_BUILD_PATH="$PWD/_build"
            export MIX_DEPS_PATH="$PWD/deps"

            # --- THE BUILDER'S BRIDGE (Clang Supremacy) ---
            export LIBCLANG_PATH="${pkgs.libclang.lib}/lib"

            # CRITICAL: Bindgen headers for Rust/C++ interop
            export BINDGEN_EXTRA_CLANG_ARGS=" \
              -isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.llvmPackages.libclang.version}/include \
              -isystem ${pkgs.glibc.dev}/include"

            # --- THE NEURO-SCANNER LINK (Tree-Sitter Source Paths) ---
            # We export the paths to the grammar SOURCES. 
            # The Python script will use these to compile the library on the fly.
            export TS_ELIXIR_SRC="${pkgs.tree-sitter-grammars.tree-sitter-elixir}"
            export TS_RUST_SRC="${pkgs.tree-sitter-grammars.tree-sitter-rust}"

            echo "🐝 Unified Swarm Environment Loaded"
            echo "   - Toolchain: Clang Supremacy (Verified)"
            echo "   - Context: Tree-Sitter Grammars Linked"
          '';
        };
      }
    );
}