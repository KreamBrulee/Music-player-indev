# syntax=docker/dockerfile:1

# ---- build stage: compile music_player from source ----
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY CMakeLists.txt ./
COPY include/ ./include/
COPY src/ ./src/

RUN cmake -B build -S . -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)"

# ---- runtime stage: slim image with just the binary + frontend + config ----
FROM debian:bookworm-slim AS runtime

# curl is only here for HEALTHCHECK below
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 musicplayer \
    && useradd -u 1000 -g musicplayer -M -s /usr/sbin/nologin musicplayer

WORKDIR /app

COPY --from=build --chown=musicplayer:musicplayer /app/build/music_player ./build/music_player
COPY --chown=musicplayer:musicplayer public/ ./public/
COPY --chown=musicplayer:musicplayer config.json ./config.json

# Mount point for the real music library — see docker-compose.yml.
# Created here (owned by musicplayer) so a bind mount over it never falls
# back to Docker auto-creating it as root, and so a bare `docker run` with
# no volume at all just serves an empty library instead of a startup warning.
RUN mkdir songs && chown musicplayer:musicplayer songs

USER musicplayer
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:3000/api/songs || exit 1

ENTRYPOINT ["./build/music_player"]
