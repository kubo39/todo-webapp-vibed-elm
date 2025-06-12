# syntax=docker/dockerfile:1

FROM buildpack-deps:bookworm AS build

RUN set -eux; \
    wget -O ldc2-1.41.0-linux-x86_64.tar.xz https://github.com/ldc-developers/ldc/releases/download/v1.40.1/ldc2-1.40.1-linux-x86_64.tar.xz; \
    echo "4a439457f0fe59e69d02fd6b57549fc3c87ad0f55ad9fb9e42507b6f8e327c8f *ldc2-1.41.0-linux-x86_64.tar.xz" | sha256sum -c -; \
    tar --strip-components=1 -C /usr/local -Jxf ldc2-1.41.0-linux-x86_64.tar.xz; \
    rm ldc2-1.41.0-linux-x86_64.tar.xz

WORKDIR /app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libpq-dev; \
    rm -fr /var/lib/apt/lists/*

RUN --mount=type=cache,target=/root/.dub/packages/,sharing=locked \
    --mount=type=cache,target=/root/.dub/cache/,sharing=locked \
    --mount=type=bind,source=./backend,target=/app/backend \
    make -C /app/backend fetch
RUN --mount=type=cache,target=/root/.dub/packages/,sharing=locked \
    --mount=type=cache,target=/root/.dub/cache/,sharing=locked \
    --mount=type=bind,source=./backend,target=/app/backend \
    make -C /app/backend build

FROM debian:bookworm-slim AS final

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libpq5; \
    rm -fr /var/lib/apt/lists/*

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid 1000 \
    appuser
USER appuser

WORKDIR /app
COPY /public /public
COPY --from=build /bin/server /app

ENV SERVER_HOST="0.0.0.0"

EXPOSE 8080

ENTRYPOINT [ "/app/server" ]
