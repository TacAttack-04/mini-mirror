FROM archlinux:latest

# Set environment variables
ENV MIRROR_DIR="/srv/http/mirror"
ENV MIRROR_NAME="my-aur-mirror"

# Update system and install dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        lighttpd \
        moreutils \
        base-devel \
        git \
        sudo \
        && pacman -Scc --noconfirm

# Create a non-root user for building packages (AUR packages can't be built as root)
RUN groupadd -g 1000 builder && \
    useradd -m -u 1000 -g builder builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create mirror directory
RUN mkdir -p "$MIRROR_DIR" && \
    chown -R builder:builder "$MIRROR_DIR"

# Create working directories
RUN mkdir -p /tmp/aur-builds && \
    chown -R builder:builder /tmp/aur-builds

# Copy the package list
COPY packages.txt /home/builder/packages.txt
RUN chown builder:builder /home/builder/packages.txt

# Copy and modify the build script
COPY aur-build-mirror.sh /home/builder/aur-build-mirror.sh
RUN chown builder:builder /home/builder/aur-build-mirror.sh && \
    chmod +x /home/builder/aur-build-mirror.sh

# Configure lighttpd
RUN cat > /etc/lighttpd/lighttpd.conf << 'EOF'
server.modules = ("mod_alias", "mod_dirlisting")
server.document-root = "/srv/http/mirror"
server.port = 8080
server.bind = "0.0.0.0"
dir-listing.activate = "enable"
index-file.names = ( "index.html" )
mimetype.assign = (
  ".tar.xz" => "application/x-xz",
  ".tar.gz" => "application/gzip",
  ".pkg.tar.xz" => "application/x-xz",
  ".pkg.tar.zst" => "application/zstd"
)
EOF

RUN cat > /identity-test.sh << 'EOF'
#!/bin/bash
set -e
echo "user: $(whoami)"
echo "home directory: $HOME"
ehco "working directory: $(pwd)"

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Your user is set to root it must be changed"
    exit 1
fi
EOF

# Expose HTTP port
EXPOSE 8080

# Switch to builder user for the build process
USER builder
WORKDIR /home/builder

# Default command
ENRTYPOINT ["./aur-build-mirror.sh"]
