# syntax=docker/dockerfile:1

FROM buildpack-deps:bookworm AS build

RUN set -eux; \
    wget -O ldc2-1.40.1-linux-x86_64.tar.xz https://github.com/ldc-developers/ldc/releases/download/v1.40.1/ldc2-1.40.1-linux-x86_64.tar.xz; \
    echo "085a593dba4b1385ec03e7521aa97356e5a7d9f6194303eccb3c1e35935c69d8 *ldc2-1.40.1-linux-x86_64.tar.xz" | sha256sum -c -; \
    tar --strip-components=1 -C /usr/local -Jxf ldc2-1.40.1-linux-x86_64.tar.xz; \
    rm ldc2-1.40.1-linux-x86_64.tar.xz

WORKDIR /app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libpq-dev; \
    rm -fr /var/lib/apt/lists/*

COPY . .

RUN make build-backend

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
COPY --from=build /app/backend/backend /app

ENV SERVER_HOST="0.0.0.0"

EXPOSE 8080

ENTRYPOINT [ "/app/backend" ]
