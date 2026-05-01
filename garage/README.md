# Garage S3 Object Storage

Single-node deployment of [Garage](https://garagehq.deuxfleurs.fr/) — an S3-compatible distributed object storage designed for self-hosting at small-to-medium scale.

## Architecture

```
garaged (v2.2.0)     — Garage S3 daemon (ports 3600-3603)
garage-ui (v0.2.2)   — Web UI for managing Garage (port 3609)
```

## Quick Start

```bash
# 1. Start services (no init command in docker-compose)
docker compose up -d

# 2. Initialize the cluster — run manually on the host, once, on first start only
bash scripts/setup-init.sh
```

After init, access the UI at `http://localhost:3609`. Default credentials:
- **Username:** `admin`
- **Password:** `xK9#vP2Lz!mN5q` (see `.env`)

## What Each Service Does

### `garaged`

The core Garage daemon. It runs the S3 API, admin API, metrics endpoint, and handles all data storage and retrieval.

**Ports:**
| Port | Purpose |
|------|---------|
| 3600 | S3 API (bucket/object operations) |
| 3601 | RPC (internal cluster communication) |
| 3602 | S3 Web (static website hosting) |
| 3603 | Admin API (management, metrics) |

### `garage-ui`

A web dashboard for managing Garage. You can browse buckets, upload/download objects, manage access keys, and view cluster status.

**Port:** 3609

### `setup-init.sh` (cluster initialization)

> **Manual step — run on your host machine, not in Docker.** No auto-init in docker-compose. You must execute this yourself after `docker compose up -d`.

This script configures the Garage cluster layout on first start. It does three things:

1. **Waits for `garaged`** to be fully ready (up to 30 seconds)
2. **Gets the node ID** — a unique identifier generated from the node's key pair
3. **Creates the cluster layout** by running:
    - `garage layout assign <node_id> -z dc1 -c 1G -t main`
    - `garage layout apply --version 1`

#### Why `layout assign` is required

Garage does not use data automatically just because the daemon is running. Before it accepts S3 writes, you must tell Garage **how** to use this node — its zone, disk capacity, and what role it plays in the cluster. This is called the "cluster layout" and it is Garage's equivalent of partition assignment in other distributed storage systems (like Kafka or Cassandra).

`garage layout assign` does this:
- **`-z dc1`** — assigns the node to a zone (datacenter). Used for fault tolerance in multi-node setups
- **`-c 1G`** — declares how much usable disk space this node has. Used to calculate data placement
- **`-t main`** — assigns a role tag. In single-node setups this is always `main`

`garage layout apply` then finalizes the assignment and activates the node. Until you run these two commands, `garage status` will show `NO ROLE ASSIGNED` and S3 write operations will fail.

The script is idempotent: it checks the current layout version and skips if the layout already exists (version > 0).

### `setup-garage-s3-keys.sh` (S3 access keys)

> **Manual step — run on your host machine.**

Creates S3 access keys (Access Key ID + Secret Key) that external services use to connect to Garage via the S3 API. Garage comes with no keys — you must create one before any S3 operations work.

Usage:
```bash
# Create key with default name "kestra-key"
bash scripts/setup-garage-s3-keys.sh

# Create key with custom name
bash scripts/setup-garage-s3-keys.sh my-service-key
```

The script:
1. Checks that `garaged` is running
2. Checks if the key already exists (won't duplicate)
3. Creates the key via `garage key create`
4. Shows the Key ID and Secret, then tells you to add them to `.env` and grant bucket permissions


**Do not add this to docker-compose.** There is no auto-init. You run it manually on the host, once, after the very first `docker compose up -d`. Re-running it later is safe — it detects the existing layout and skips.

## Configuration

### `garage.toml`

| Setting | Value | Description |
|---------|-------|-------------|
| `metadata_dir` | `/var/lib/garage/meta` | SQLite/LMDB database location |
| `data_dir` | `/var/lib/garage/data` | Stored object data location |
| `db_engine` | `lmdb` | Database engine (also supports `sqlite`) |
| `replication_factor` | `1` | Single-node: keep at 1. Increase for multi-node HA |
| `compression_level` | `1` | Low compression for better CPU/speed tradeoff |
| `rpc_secret` | *(see `.env`)* | Shared secret for node-to-node authentication. Must be identical across all cluster nodes |

**S3 API** (port 3600):
- `s3_region`: `garage`
- `root_domain`: `.s3.garage.localhost` — S3 endpoint URLs follow `<bucket>.s3.garage.localhost`

**S3 Web** (port 3602):
- `root_domain`: `.web.garage.localhost` — Static hosting follows `<bucket>.web.garage.localhost`
- `index`: `index.html` — Default index file

**Admin** (port 3603):
- `metrics_require_token`: `false` — Metrics endpoint accessible without token (convenient for local dev)

### `.env`

Environment variables injected into containers at runtime:

| Variable | Used By | Purpose |
|----------|---------|---------|
| `GARAGE_RPC_SECRET` | garaged | Network authentication between nodes |
| `GARAGE_ADMIN_TOKEN` | garaged, garage-ui | Admin API authentication |
| `GARAGE_METRICS_TOKEN` | garaged | Metrics endpoint authentication |
| `GARAGE_UI_AUTH_ADMIN_PASSWORD` | garage-ui | Admin panel password |
| `GARAGE_UI_AUTH_OIDC_CLIENT_SECRET` | garage-ui | Optional OIDC/OAuth2 client secret |

## Common Operations

### CLI Commands (run inside garaged container)

```bash
# Check cluster status
docker exec garaged /garage status

# View cluster layout
docker exec garaged /garage layout show

# Get node ID
docker exec garaged /garage node id

# List buckets
docker exec garaged /garage bucket list

# Create a bucket
docker exec garaged /garage bucket create my-bucket

# Delete a bucket
docker exec garaged /garage bucket delete my-bucket

# List S3 access keys
docker exec garaged /garage key list

# Create an S3 access key
docker exec garaged /garage key create my-app-key

# Delete an S3 access key
docker exec garaged /garage key delete my-app-key

# Show all keys and grant permissions
docker exec garaged /garage key info my-app-key
docker exec garaged /garage bucket allow my-bucket --read --write --key my-app-key

# View stats
docker exec garaged /garage stats

# Backup metadata database
docker exec garaged /garage meta snapshot

# Check logs
docker logs garaged
```

### S3 Client Configuration

Point your S3 client (rclone, minio client, AWS CLI, etc.) to:

```
Endpoint:    http://localhost:3600
Region:      garage
Access Key:  <from garage key create>
Secret Key:  <from garage key create>
Force Path:  true
```

For website hosting: `http://<bucket-name>.web.garage.localhost:3602`
For S3 API: `<bucket-name>.s3.garage.localhost:3600`

### Backup

```bash
# Snapshot the metadata database
docker exec garaged /garage meta snapshot

# Copy the snapshot file
cp /home/nobu/projects/infra-blueprints/garage/meta/snapshots/* ./backup/

# Also backup the data directory
tar czf garage-data-backup.tar.gz ./data/
```

### Restore

```bash
# Stop garaged
docker compose stop garaged

# Restore metadata snapshots
cp ./backup/*.snapshot ./garage/meta/snapshots/

# Restore data (if needed)
rm -rf ./data/*
tar xzf garage-data-backup.tar.gz

# Restart
docker compose up -d garaged
```

## Important Warnings

### 1. Never delete `meta/` or `data/`

These directories contain your metadata database and stored objects. Deleting them means **permanent data loss**.

### 2. Backup before upgrading

```bash
docker compose stop
tar czf pre-upgrade-backup.tar.gz ./meta/ ./data/ ./config/
docker compose up -d
```

### 3. `replication_factor = 1` means no redundancy

This is a single-node deployment. If the disk fails, data is lost. For production, deploy multiple nodes and set `replication_factor = 3` in `config/garage.toml`.

### 4. The `dxflrs/garage` image has no shell

The Garage Docker image is minimal — it contains only the `/garage` binary. It does **not** have `sh`, `bash`, or `ls`. This is why:
- The original `garage-init` service (which ran `sh -c "..."`) failed with `"sh": executable file not found`
- Init is now a separate script (`scripts/setup-init.sh`) that runs on the host via `docker exec`

### 5. RPC secret must be identical across all cluster nodes

In multi-node setups, every node must use the same `rpc_secret` value. Changing it requires reinitializing all nodes.

### 6. Layout version increments on each change

Every time you add/remove nodes or change roles, the layout version increases. You can view the full history with:
```bash
docker exec garaged /garage layout history
```

To revert to a previous layout:
```bash
docker exec garaged /garage layout revert --version <previous_version>
```

### 7. Disk space monitoring

Garage does not auto-delete data. Monitor disk usage:
```bash
du -sh ./data/
du -sh ./meta/

# Check Garage stats
docker exec garaged /garage stats -a
```

### 8. Default secrets are for development only

The `.env` values in this repo are example/development values. For production, generate new secrets:

```bash
# Generate RPC secret (32 bytes hex)
openssl rand -hex 32

# Generate admin token
openssl rand -base64 32

# Generate metrics token
openssl rand -base64 32
```

Then update `.env` and restart.

## Troubleshooting

### `garage-ui` fails with "config.yaml: is a directory"

The `config/garage-ui-config.yaml` file must be a file, not a directory. Remove the directory and create the file:
```bash
rm -rf ./config/garage-ui-config.yaml
# Then create a new one with the contents from this repo
docker compose up -d --force-recreate garage-ui
```

### `garaged` won't start

Check logs:
```bash
docker logs garaged
```

Common causes:
- Missing volume permissions: `sudo chown -R 999:999 ./meta ./data`
- Corrupted LMDB: check `./meta/` for lock files from a crash

### `setup-init.sh` fails with "garaged did not start in time"

Wait longer and check:
```bash
docker logs garaged --tail 50
```

### S3 operations fail with "Access Denied"

Create an access key and grant bucket permissions:
```bash
docker exec garaged /garage key create my-key
docker exec garaged /garage bucket allow my-bucket --read --write --key my-key
```

### Layout changes are stuck

```bash
# View staged changes
docker exec garaged /garage layout show

# Revert staged changes
docker exec garaged /garage layout revert

# Or apply them
docker exec garaged /garage layout apply --version <next_version>
```

## File Structure

```
garage/
├── docker-compose.yml          # Service definitions
├── .env                        # Environment variables (secrets)
├── config/
│   ├── garage.toml             # Garage daemon configuration
│   └── garage-ui-config.yaml   # Web UI configuration
├── meta/                       # Metadata database (DO NOT DELETE)
├── data/                       # Stored objects (DO NOT DELETE)
└── scripts/
    ├── setup-init.sh           # Cluster layout initialization (run once)
    └── setup-garage-s3-keys.sh # Create S3 access keys
```

## References

- [Garage Documentation](https://garagehq.deuxfleurs.fr/documentation/)
- [Quick Start](https://garagehq.deuxfleurs.fr/documentation/quick-start)
- [Configuration Reference](https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration)
- [Layout Operations](https://garagehq.deuxfleurs.fr/documentation/operations/layout)
- [Garage UI](https://github.com/noooste/garage-ui)
