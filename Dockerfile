# Web build of Prism for Railway (or any container host).
#
# Stage 1 builds the Flutter web app; stage 2 serves the static files with
# Caddy. The web build is local-only: data lives in the browser, and sync,
# pairing and notifications are unavailable (see docs/deploy/railway.md).

# ---------------------------------------------------------------------------
# Stage 1: build
# ---------------------------------------------------------------------------
# buildpack-deps already ships curl, git, xz and unzip, so no apt step.
FROM buildpack-deps:bookworm AS build

ARG FLUTTER_VERSION=3.44.1

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt \
 && git config --global --add safe.directory '*'
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web >/dev/null \
 && flutter precache --web

WORKDIR /app

# Resolve dependencies first so this layer is cached between code changes.
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
RUN flutter pub get

COPY . .
RUN ./scripts/build_web.sh

# ---------------------------------------------------------------------------
# Stage 2: serve
# ---------------------------------------------------------------------------
FROM caddy:2-alpine

COPY deploy/web/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/build/web /srv

# Railway injects PORT; Caddy listens on it (defaults to 8080 locally).
ENV PORT=8080
EXPOSE 8080
