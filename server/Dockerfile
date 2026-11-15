# Prism Social server for Railway (or any container host).
# Build from the repository root so the shared rules package is included:
#   docker build -f server/Dockerfile .

FROM dart:3.11 AS build
WORKDIR /src
# Dependencies first, so this layer is cached between code changes.
COPY packages/prism_social_core/pubspec.yaml packages/prism_social_core/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN mkdir -p packages/prism_social_core/lib \
 && cd server && dart pub get
COPY packages/prism_social_core packages/prism_social_core
COPY server server
RUN mkdir -p /out && cd server && dart pub get --offline && dart compile exe bin/server.dart -o /out/server

# Small runtime image: the AOT binary plus the runtime libraries it needs.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
