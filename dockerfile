FROM archlinux:latest

# Completely reset pacman state
RUN rm -rf /var/cache/pacman/pkg/* && \
    rm -rf /var/lib/pacman/sync/* && \
    echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist && \
    echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist && \
    pacman -Syy

# Set environment variables
ENV MIRROR_DIR="/srv/http/mirror"
ENV MIRROR_NAME="my-aur-mirror"
ENV UID="1000"
ENV GID="1000"

# Replace problematic mirrors immediately
RUN echo 'Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist && \
    echo 'Server = https://mirror.arizona.edu/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist 

# Update system and install dependencies
RUN pacman -Syy --noconfirm && \
    pacman -S --noconfirm \
        lighttpd \
        moreutils \
        base-devel \
        git \
        sudo \
        cron \
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

# Create cron directories
RUN mkdir -p /var/run /var/log && \
    touch /var/run/crond.pid /etc/chrontab && \
    chown -R builder:builder /var/run /var/log && \
    chown builder:builder /etc/chrontab

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
COPY ./startup/* /home/builder/startup/

# Mod all scripts so they can be used
RUN chmod +x /home/builder/startup/*.sh

# Sets ownership of everything in builder directory to builder
RUN chown -R builder:builder /home/builder/

# Makes everything in /tmp rw able by everyone
RUN chmod 1777 /tmp

# Switch to builder user for the build process
USER builder
WORKDIR /home/builder

# Default command
ENTRYPOINT ["./startup/entrypoint.sh"]
