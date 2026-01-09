#!/usr/bin/env bash


# 🕵️ Auto-detect the local LAN IP
# This grabs the first non-loopback IP address. 
# If it guesses wrong on the HP, just hardcode IP="192.168.1.147"
IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

# If ifconfig is missing in NixOS minimal, use 'ip':
if [ -z "$IP" ]; then
    IP=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
fi

NAME="brain@$IP"
COOKIE="swarm_class_a_secret"

# ... (after setting IP and NAME)

# OPTIONAL: "Scout Protocol"
# If this is the ASUS, and we have no memory, ensure we start fresh to accept the HP's brain.
if [[ "$NAME" == *"192.168.1.243"* ]]; then
    if [ ! -d "Mnesia.$NAME" ]; then
        echo "🧹 Scout Mode: Starting with clean slate for adoption..."
        # No action needed, just ensuring we don't have a partial conflict
    fi
    # If you ever get the FATAL error again, un-comment this line to auto-heal:
    # rm -rf Mnesia.$NAME* fi

echo "🚀 IGNITING SWARM NODE: $NAME"
echo "   - 🍪 Cookie: Class A Secret"
echo "   - 🛣️  Ports: 40000-40100 (Firewall Lane)"

# The Magic Command
iex --name "$NAME" \
    --cookie "$COOKIE" \
    --erl "-kernel inet_dist_listen_min 40000 inet_dist_listen_max 40100" \
    -S mix