#!/bin/bash
# Garage S3 Key Setup Script
# Creates S3 access keys for Garage and updates .env file

set -e

KEY_NAME="${1:-kestra-key}"
ENV_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_DIR}/.env"

echo "=== Garage S3 Key Setup ==="
echo "Key name: $KEY_NAME"
echo ""

# Check if garaged container is running
if ! docker ps --format '{{.Names}}' | grep -q "^garaged$"; then
  echo "ERROR: garaged container is not running!"
  echo "Start it with: cd garage-s3 && docker compose up -d"
  exit 1
fi

# Check if key already exists
echo "Checking if key '$KEY_NAME' already exists..."
EXISTS=$(docker exec garaged garage key list 2>/dev/null | grep -c "$KEY_NAME" || true)
if [ "$EXISTS" -gt 0 ]; then
  echo "Key '$KEY_NAME' already exists. To recreate, run:"
  echo "  docker exec garaged garage key delete $KEY_NAME"
  echo ""
  echo "Retrieving existing key info..."
  docker exec garaged garage key info "$KEY_NAME"
  exit 0
fi

# Create the key
echo "Creating key '$KEY_NAME'..."
docker exec garaged garage key create "$KEY_NAME"
echo ""

# List all keys
echo "All Garage S3 keys:"
docker exec garaged garage key list
echo ""

# Instructions to add to .env
echo "=== Next Steps ==="
echo ""
echo "1. Copy the Key ID and Secret from above"
echo "2. Update .env file:"
echo "   GARAGE_S3_ACCESS_KEY=<your-key-id>"
echo "   GARAGE_S3_SECRET_KEY=<your-secret>"
echo ""
echo "3. Create a bucket and grant permissions:"
echo "   docker exec garaged garage bucket create raw-data"
echo "   docker exec garaged garage bucket allow raw-data --read --write --key $KEY_NAME"
echo ""
echo "4. Restart ClickHouse to pick up new credentials"
