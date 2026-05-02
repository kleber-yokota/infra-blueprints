# Local Models

Local language models served via `llama.cpp` for use with OpenCode.

## Model

| Field | Value |
|-------|-------|
| Model | Qwen3.6-35B-A3B |
| Format | GGUF |
| Quantization | Q4_K_XL |
| Size | ~21 GB |
| Context | 262K tokens |

## Requirements

- NVIDIA GPU with CUDA support (24GB VRAM recommended)
- Docker with NVIDIA runtime

## Usage with OpenCode

The model runs as a local backend for OpenCode at `http://localhost:8181`.

## Setup

Copy the environment template and add your HuggingFace token:

```bash
cp llama/.env.example llama/.env
# Edit llama/.env and add your HF_TOKEN
```

## Commands

```bash
# Start (downloads model automatically)
docker compose -f llama/docker-compose.yml up -d

# Stop
docker compose -f llama/docker-compose.yml down

# View logs
docker compose -f llama/docker-compose.yml logs -f

# Test endpoint
curl -s http://localhost:8181/docs
```

## docker-compose.yml

Two services:

- **`download`** — Downloads the model from HuggingFace automatically
- **`llama`** — Serves the model via HTTP at `localhost:8181`

### Server Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--model` | `/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` | GGUF model path |
| `--ctx-size` | `262144` | Context window size |
| `--cache-type-k` | `q8_0` | KV cache for attention K |
| `--cache-type-v` | `q8_0` | KV cache for attention V |
| `--parallel` | `1` | Parallel requests |

## Downloads

The model is downloaded automatically from HuggingFace:

```
unsloth/Qwen3.6-35B-A3B-GGUF
→ Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
```
