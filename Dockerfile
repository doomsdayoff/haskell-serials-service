FROM haskell:9.6 AS build
WORKDIR /build

# Зависимости кэшируются отдельным слоем: правка исходников их не пересобирает.
COPY serials-api.cabal ./
RUN cabal update && cabal build --only-dependencies

COPY . .
RUN cabal install exe:serials-api --installdir=/out --install-method=copy

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libgmp10 \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/serials-api /usr/local/bin/serials-api
COPY serials.json ./
ENV PORT=8080
EXPOSE 8080
CMD ["serials-api"]
