#!/usr/bin/env bash
set -euo pipefail

# ─── AnimaDex Docker Entrypoint ───
# Handles first-run setup: config, secret key, DB schema, sample seeding.

DATA_DIR="/app/data"
CONFIG_FILE="/app/config.toml"

# ─── 1. Generate config.toml if missing ───
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[entrypoint] Creating config.toml from example..."
    cp /app/config.toml.example "$CONFIG_FILE"
fi

# ─── 2. Generate secret key if not set via env or config ───
if [ -z "${ANIMADEX_SERVER_SECRET_KEY:-}" ]; then
    # Check if config.toml has an empty secret_key
    CURRENT_KEY=$(python3 -c "
import tomllib
with open('$CONFIG_FILE', 'rb') as f:
    cfg = tomllib.load(f)
print(cfg.get('server', {}).get('secret_key', ''))
" 2>/dev/null || echo "")
    if [ -z "$CURRENT_KEY" ]; then
        GENKEY=$(python -m animadex genkey 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
        export ANIMADEX_SERVER_SECRET_KEY="$GENKEY"
        echo "[entrypoint] Generated secret key (set ANIMADEX_SERVER_SECRET_KEY to override)."
    fi
fi

# ─── 3. Initialize database + data dirs ───
echo "[entrypoint] Initializing database..."
python -m animadex db-init 2>/dev/null || true

# ─── 4. Seed samples on first run ───
if [ -d "/app/samples" ] && [ ! -e "${DATA_DIR}/.seeded" ]; then
    echo "[entrypoint] Seeding sample data..."
    mkdir -p "${DATA_DIR}/characters/thumbs" \
             "${DATA_DIR}/artists/thumbs" \
             "${DATA_DIR}/copyrights/thumbs"
    cp -r /app/samples/images/characters/thumbs/* \
          "${DATA_DIR}/characters/thumbs/" 2>/dev/null || true
    cp -r /app/samples/images/artists/thumbs/* \
          "${DATA_DIR}/artists/thumbs/" 2>/dev/null || true
    cp -r /app/samples/images/copyrights/thumbs/* \
          "${DATA_DIR}/copyrights/thumbs/" 2>/dev/null || true
    python -m animadex build-db /app/samples/characters.csv --mode characters 2>/dev/null || true
    python -m animadex build-db /app/samples/artists.csv --mode artists 2>/dev/null || true
    touch "${DATA_DIR}/.seeded"
    echo "[entrypoint] Sample data seeded successfully."
fi

echo "[entrypoint] Starting AnimaDex..."
exec "$@"
