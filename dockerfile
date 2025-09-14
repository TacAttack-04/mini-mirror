FROM archlinux:latest

# Set environment variables
ENV MIRROR_DIR="/srv/http/mirror"
ENV MIRROR_NAME="my-aur-mirror"
ENV UID="1000"
ENV GID="1000"


# Update system and install dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        lighttpd \
        moreutils \
        base-devel \
        git \
        sudo \
        cronie \
        && pacman -Scc --noconfirm

# Create a non-root user for building packages (AUR packages can't be built as root)
RUN groupadd -g "$GID" builder && \
    useradd -m -u "$UID" -g builder builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create mirror directory
RUN mkdir -p "$MIRROR_DIR" && \
    chown -R builder:builder "$MIRROR_DIR"

# Create working directories
RUN mkdir -p /tmp/aur-builds && \
    chown -R builder:builder /tmp/aur-builds

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

# Expose HTTP port
EXPOSE 8080

# Copy files into builder space
COPY ["aur-build-mirror.sh", "entrypoint.sh", "packages.txt", "identity-test.sh", "/home/builder/startup/"]

# Mod all scripts so they can be used
RUN chmod +x /home/builder/*.sh

# Sets ownership of everything in builder directory to builder
RUN chown -R builder:builder /home/builder/

# Makes everything in /tmp rw able by everyone
RUN chmod 1777 /tmp

# Switch to builder user for the build process
USER builder
WORKDIR /home/builder

# Default command
ENTRYPOINT ["./entrypoint.sh"]
