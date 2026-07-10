# Dockerfile for mini-render control plane

FROM nimlang/nim:2.0.0 AS builder

WORKDIR /app
COPY package.nimble .
COPY src/ src/

# Install deps and compile a release binary
RUN nimble install -y jester
RUN nim c -d:release --opt:speed -o:server src/server.nim

# --- Runtime stage: smaller final image ---
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=builder /app/server .

# This is where provisioned .sqlite3 files will live —
# mount a persistent volume/disk here on your cloud platform,
# otherwise data is lost every time the container restarts.
RUN mkdir -p /app/data/databases

EXPOSE 5000
CMD ["./server"]
