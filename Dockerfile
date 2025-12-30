# ---------- Stage 1 : Build the FileBrowser binary ----------
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Install required build tools
RUN apk add --no-cache git nodejs npm

# Copy source code
COPY . .

# Download Go dependencies
RUN go mod download

# ---------- Build frontend ----------
WORKDIR /app/frontend
RUN npm install && npm run build

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

# Create required directories
RUN mkdir -p /config /database /srv && \
    chown -R user:user /config /database /srv

USER user
EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--", "/bin/filebrowser"]





