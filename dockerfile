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
RUN useradd -m -G wheel -s /bin/bash builder && \
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

# Fix the script syntax errors and make it work in Docker
RUN sed -i 's|mkdir -p "MIRROR_DIR"|mkdir -p "$MIRROR_DIR"|' /home/builder/aur-build-mirror.sh && \
    sed -i 's|if \[ ! -d "/tmp/$package \]; then|if [ ! -d "/tmp/aur-builds/$package" ]; then|' /home/builder/aur-build-mirror.sh && \
    sed -i 's|git clone "https://aur.archlinux.org/${package}.git" "/tmp/$package"|git clone "https://aur.archlinux.org/${package}.git" "/tmp/aur-builds/$package"|' /home/builder/aur-build-mirror.sh && \
    sed -i 's|cd "/tmp/$package"|cd "/tmp/aur-builds/$package"|' /home/builder/aur-build-mirror.sh && \
    sed -i 's|mv \*.pkg.tar.\* "MIRROR_DIR/"|mv *.pkg.tar.* "$MIRROR_DIR/"|' /home/builder/aur-build-mirror.sh

# Configure lighttpd
RUN echo 'server.modules = ("mod_alias", "mod_dirlisting")' > /etc/lighttpd/lighttpd.conf && \
    echo 'server.document-root = "/srv/http/mirror"' >> /etc/lighttpd/lighttpd.conf && \
    echo 'server.port = 8080' >> /etc/lighttpd/lighttpd.conf && \
    echo 'server.bind = "0.0.0.0"' >> /etc/lighttpd/lighttpd.conf && \
    echo 'dir-listing.activate = "enable"' >> /etc/lighttpd/lighttpd.conf && \
    echo 'index-file.names = ( "index.html" )' >> /etc/lighttpd/lighttpd.conf

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash
# Start lighttpd in background
lighttpd -f /etc/lighttpd/lighttpd.conf -D &

# Switch to builder user and run the AUR build script
su - builder -c "/home/builder/aur-build-mirror.sh"

# Keep lighttpd running
wait
EOF

RUN chmod +x /start.sh

# Expose HTTP port
EXPOSE 8080

# Switch to builder user for the build process
USER builder
WORKDIR /home/builder

# Default command
CMD ["sudo", "/start.sh"]
