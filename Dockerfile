# ─── AnimaDex Dockerfile ───
# Self-hosted, searchable gallery for AI-generated anime character/artist references.
#
# Build:   docker build -t animadex .
# Run:     docker run -p 5000:5000 -v animadex-data:/app/data animadex
# Compose: docker compose up -d

FROM python:3.12-slim AS base

LABEL maintainer="hazumin"
LABEL description="AnimaDex – self-hosted anime character/artist reference gallery"

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system deps required by Pillow (JPEG/WebP support)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libffi-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ─── Install Python dependencies ───
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ─── Copy application code ───
COPY pyproject.toml ./
COPY animadex/ ./animadex/
COPY samples/ ./samples/
COPY config.toml.example ./

# ─── Install the package in editable-like mode ───
RUN pip install --no-cache-dir -e .

# ─── Create data directory and generate default config ───
RUN mkdir -p /app/data

# Copy the entrypoint script
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 5000

# Default data volume
VOLUME ["/app/data"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["python", "-m", "animadex", "serve"]
