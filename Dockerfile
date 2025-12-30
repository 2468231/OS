# ---------- Stage 1 : Build the FileBrowser binary ----------
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Install build tools
RUN apk add --no-cache git nodejs npm

# Install pnpm (used by FileBrowser frontend)
RUN npm install -g pnpm

# Copy source code
COPY . .

# Download Go dependencies
RUN go mod download

# ---------- Build frontend ----------
WORKDIR /app/frontend
RUN pnpm install && pnpm run build

# ---------- Build backend binary ----------
WORKDIR /app
RUN go build -o filebrowser .

# ---------- Stage 2 : Runtime image ----------
FROM alpine:3.18

# Install minimal runtime dependencies
RUN apk add --no-cache ca-certificates tini mailcap

# Create a non-root user
RUN addgroup -g 1000 user && adduser -D -u 1000 -G user user

# Copy compiled binary from builder
COPY --from=builder /app/filebrowser /bin/filebrowser

# Create writable directories
RUN mkdir -p /home/user/config /home/user/database /home/user/srv && \
    chown -R user:user /home/user

USER user
WORKDIR /home/user

# Render uses dynamic port detection, so expose $PORT
EXPOSE 10000

# Run FileBrowser bound to 0.0.0.0 (so Render detects it)
ENTRYPOINT ["/sbin/tini", "--", "/bin/filebrowser", \
    "--database", "/home/user/database/filebrowser.db", \
    "--root", "/home/user/srv", \
    "--address", "0.0.0.0", \
    "--port", "10000"]






