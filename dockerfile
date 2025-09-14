FROM archlinux:latest

# Set environment variables
ENV MIRROR_DIR="/srv/http/mirror"
ENV MIRROR_NAME="my-aur-mirror"
ENV UID="1000"
ENV GID="1000"

# Temporarily use public DNS for package installation to prevent docker dns errors
RUN cp /etc/resolv.conf /etc/resolv.conf.backup && \
    echo "nameserver 8.8.8.8" > /etc/resolv.conf && \
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf && \
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf && \
    pacman -Syy --noconfirm && \
    pacman -S --noconfirm \
        lighttpd \
        moreutils \
        base-devel \
        git \
        sudo \
        cron \
        && pacman -Scc --noconfirm && \
    mv /etc/resolv.conf.backup /etc/resolv.conf

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
RUN mkdir -p /var/run /var/log /home/builder/.cache/crontab && \
    touch /var/run/crond.pid /etc/chrontab && \
    chown -R builder:builder /var/run /var/log && \
    chown builder:builder /etc/chrontab

# Configure lighttpd
COPY ./config/lighttpd.conf /etc/lighttpd/lighttpd.conf

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
