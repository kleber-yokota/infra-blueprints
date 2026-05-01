#!/bin/bash
# Garage Cluster Layout Initialization Script
# Run once after first start to create the cluster layout

set -e

echo "=== Garage Init ==="

GARBIN=/garage

# Wait for garaged to be ready
echo "Waiting for garaged to start..."
for i in $(seq 1 30); do
    if docker exec garaged "$GARBIN" status >/dev/null 2>&1; then
        echo "garaged is ready!"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 1
done

if ! docker exec garaged "$GARBIN" status >/dev/null 2>&1; then
    echo "ERROR: garaged did not start in time"
    exit 1
fi

# Get node ID
NODE_ID=$(docker exec garaged "$GARBIN" node id 2>/dev/null | grep -oE '^[a-f0-9]{16}' || true)

if [ -z "$NODE_ID" ]; then
    echo "ERROR: Could not get node ID"
    exit 1
fi

echo "Node ID: $NODE_ID"

# Check current layout version
LAYOUT_OUTPUT=$(docker exec garaged "$GARBIN" layout show 2>&1)
VERSION=$(echo "$LAYOUT_OUTPUT" | grep -oE 'Current cluster layout version: [0-9]+' | grep -oE '[0-9]+' || echo "0")

echo "Current layout version: $VERSION"

if [ "$VERSION" = "0" ]; then
    echo "Applying cluster layout for node: $NODE_ID"
    docker exec garaged "$GARBIN" layout assign "$NODE_ID" -z dc1 -c 1G -t main
    docker exec garaged "$GARBIN" layout apply --version 1
    echo "Layout applied successfully!"
else
    echo "Layout already applied (version $VERSION), skipping."
fi

echo "=== Garage Init Complete ==="
