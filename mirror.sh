#!/usr/bin/env bash

# HP -> ASUS Sync
TARGET_IP="192.168.1.243" # Put your ASUS IP here
TARGET_DIR="~/brain/"

echo "🚀 Swarm Intelligence Flow: HP -> ASUS"

# We watch EVERYTHING in the folder, but use rsync's exclusion to stay light.
# This way, if you edit mix.exs or flake.nix, the ASUS gets it too.
ls -d ./* | entr -d rsync -avz \
    --exclude '_build' \
    --exclude 'deps' \
    --exclude '.git' \
    --exclude '.direnv' \
    . buddha@$TARGET_IP:$TARGET_DIR