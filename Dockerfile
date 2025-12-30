# ---------- Stage 1: Build the FileBrowser binary ----------
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Install dependencies and copy source
RUN apk add --no-cache git
COPY . .
RUN go mod download
RUN go build -o filebrowser .

# ---------- Stage 2: Runtime image ----------
FROM alpine:3.18

# Install minimal runtime dependencies
RUN apk add --no-cache ca-certificates tini mailcap

# Create a non-root user
RUN addgroup -g 1000 user && adduser -D -u 1000 -G user user

# Copy binary from builder
COPY --from=builder /app/filebrowser /bin/filebrowser

# Create directories for data/config
RUN mkdir -p /config /database /srv && \
    chown -R user:user /config /database /srv

USER user
EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--", "/bin/filebrowser"]



