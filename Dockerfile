## Multistage build: First stage fetches dependencies
FROM alpine:3.23 AS fetcher

# install and copy ca-certificates, mailcap, and tini-static; download JSON.sh
RUN apk update && \
    apk --no-cache add ca-certificates mailcap tini-static && \
    wget -O /JSON.sh https://raw.githubusercontent.com/dominictarr/JSON.sh/0d5e5c77365f63809bf6e77ef44a1f34b0e05840/JSON.sh

## Second stage: Use lightweight BusyBox image for final runtime environment
FROM busybox:1.37.0-musl

# Define non-root user UID and GID
ENV UID=1000
ENV GID=1000

# Create user group and user
RUN addgroup -g $GID user && \
    adduser -D -u $UID -G user user

# Copy binary, scripts, and configurations into image with proper ownership
# ---------- First stage: build the FileBrowser binary ----------
FROM golang:1.22-alpine AS builder
WORKDIR /app

# Install dependencies and copy all source code
RUN apk add --no-cache git
COPY . .
RUN go mod download
RUN go build -o filebrowser .

# ---------- Second stage: lightweight runtime ----------
FROM alpine:3.18

# Create non-root user
RUN addgroup -g 1000 user && adduser -D -u 1000 -G user user

# Copy the built binary from the first stage
COPY --from=builder /app/filebrowser /bin/filebrowser

# Optional: copy configuration and helper scripts if present
# (comment these out if these folders don't exist in your fork)
# COPY --chown=user:user docker/common/ /
# COPY --chown=user:user docker/alpine/ /

USER user
EXPOSE 80
ENTRYPOINT ["/bin/filebrowser"]

COPY --chown=user:user docker/common/ /
COPY --chown=user:user docker/alpine/ /
COPY --chown=user:user --from=fetcher /sbin/tini-static /bin/tini
COPY --from=fetcher /JSON.sh /JSON.sh
COPY --from=fetcher /etc/ca-certificates.conf /etc/ca-certificates.conf
COPY --from=fetcher /etc/ca-certificates /etc/ca-certificates
COPY --from=fetcher /etc/mime.types /etc/mime.types
COPY --from=fetcher /etc/ssl /etc/ssl

# Create data directories, set ownership, and ensure healthcheck script is executable
RUN mkdir -p /config /database /srv && \
    chown -R user:user /config /database /srv \
    && chmod +x /healthcheck.sh

# Define healthcheck script
HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh

# Set the user, volumes and exposed ports
USER user

VOLUME /srv /config /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]


