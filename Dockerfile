# Estágio 1: Compilar o módulo Go
FROM golang:1.23 AS builder-go
WORKDIR /app
COPY go.mod go.sum ./
RUN go env -w GOPROXY=https://goproxy.io,direct \
    && go mod tidy \
    && go mod download
COPY src ./src
WORKDIR /app/src
RUN GODEBUG=http2client=0 go get cloud.google.com/go/pubsub \
    && go build -buildmode=c-shared -o libpubsub.so pubsub.go

# Estágio 2: Compilar o projeto Zig
FROM ziglings/ziglang:latest AS builder-zig
WORKDIR /app
COPY . .
COPY --from=builder-go /app/src/libpubsub.so /app/src/libpubsub.so
ENV LD_LIBRARY_PATH=/app/src
RUN zig build -Doptimize=ReleaseSafe

# Estágio 3: Criar a imagem final
FROM ubuntu:22.04 AS base
WORKDIR /app
COPY --from=builder-zig /app/zig-out/bin/TeltonikaTcpParserServer /app/TeltonikaTcpParserServer
COPY --from=builder-go /app/src/libpubsub.so /app/src/libpubsub.so
COPY .env /app/.env
COPY service-account-key.json /app/service-account-key.json
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/service-account-key.json
EXPOSE 4444
CMD ["./TeltonikaTcpParserServer"]