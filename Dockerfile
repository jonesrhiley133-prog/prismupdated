# Web build of Prism for Railway (or any container host).
#
# The same file also builds the Prism Social server when the build argument
# (Railway service variable) PRISM_SERVICE=server is set. Without it, the
# web app is built exactly as before. Only the selected image's stages run.
#
# Stage 1 builds the Flutter web app; stage 2 serves the static files with
# Caddy. The web build is local-only: data lives in the browser, and sync,
# pairing and notifications are unavailable (see docs/deploy/railway.md).

# ---------------------------------------------------------------------------
# Stage 1: build
# ---------------------------------------------------------------------------
# buildpack-deps already ships curl, git, xz and unzip, so no apt step.
ARG PRISM_SERVICE=web

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
# The Social server is a path dev-dependency (used by tests); pub needs its pubspec.
COPY server/pubspec.yaml server/pubspec.lock ./server/
RUN flutter pub get

COPY . .
RUN ./scripts/build_web.sh

# ---------------------------------------------------------------------------
# Stage 2: serve
# ---------------------------------------------------------------------------
FROM caddy:2-alpine AS web

COPY deploy/web/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/build/web /srv

# Railway injects PORT; Caddy listens on it (defaults to 8080 locally).
ENV PORT=8080
EXPOSE 8080

# ---------------------------------------------------------------------------
# Prism Social server (PRISM_SERVICE=server); see docs/deploy/railway-social-server.md
# ---------------------------------------------------------------------------
FROM dart:3.11 AS server-build
WORKDIR /src
COPY packages/prism_social_core/pubspec.yaml packages/prism_social_core/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN mkdir -p packages/prism_social_core/lib && cd server && dart pub get
COPY packages/prism_social_core packages/prism_social_core
COPY server server
RUN mkdir -p /out && cd server && dart pub get --offline && dart compile exe bin/server.dart -o /out/server

FROM scratch AS server
COPY --from=server-build /runtime/ /
COPY --from=server-build /out/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]

# ---------------------------------------------------------------------------
# Pick the image to produce.
# ---------------------------------------------------------------------------
FROM ${PRISM_SERVICE}
