#!/bin/bash
# aur-build-mirror.sh

MIRROR_DIR="${MIRROR_DIR:-/srv/http/mirror}"
MIRROR_NAME="${MIRROR_NAME:-my-aur-mirror}"

# Gets the absolute path to this file then uses it to find the path to packages.txt
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PACKAGES_FILE="${SCRIPT_DIR}/packages.txt"

# Ensure mirror directory exists
mkdir -p "$MIRROR_DIR"
mkdir -p /tmp/aur-builds

# Check if packages file exists
if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: packages.txt not found at $PACKAGES_FILE"
    exit 1
fi

echo "Starting AUR mirror build process..."
echo "Mirror directory: $MIRROR_DIR"
echo "Mirror name: $MIRROR_NAME"
echo "Packages file: $PACKAGES_FILE"

while IFS= read -r package; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
    
    echo "Processing package: $package"
    
    # Clone or update the package repository
    if [ ! -d "/tmp/aur-builds/$package" ]; then
        echo "Cloning $package from AUR..."
        if ! git clone "https://aur.archlinux.org/${package}.git" "/tmp/aur-builds/$package"; then
            echo "Error: Failed to clone $package. Skipping..."
            continue
        fi
    else
        echo "Updating existing $package repository..."
        cd "/tmp/aur-builds/$package"
        if ! git pull; then
            echo "Warning: Failed to update $package repository"
        fi
    fi

    cd "/tmp/aur-builds/$package" || {
        echo "Error: Cannot enter directory for $package. Skipping..."
        continue
    }

    echo "Building $package..."
    if makepkg -c -s --noconfirm; then
        echo "Successfully built $package"
        
        # Move built packages to mirror
        echo "Moving $package to mirror..."
        if ls *.pkg.tar.* 1> /dev/null 2>&1; then
            mv *.pkg.tar.* "$MIRROR_DIR/" || {
                echo "Error: Failed to move $package files to mirror"
                continue
            }
        else
            echo "Warning: No package files found for $package"
        fi
    else
        echo "Error: Failed to build $package. Skipping..."
        continue
    fi

done < "$PACKAGES_FILE"

echo "Cleaning up build dependencies..."
# Clean up leftover makepkg dependencies (commented out as it might be too aggressive in Docker)
# pacman -Qdttq | ifne pacman -Rns --noconfirm -

echo "Creating repository database..."
cd "$MIRROR_DIR" || exit 1

if ls *.pkg.tar.* 1> /dev/null 2>&1; then
    repo-add "${MIRROR_NAME}.db.tar.gz" *.pkg.tar.*
    echo "Repository database created successfully!"
    echo "Mirror is ready at: $MIRROR_DIR"
    echo "Total packages built: $(ls -1 *.pkg.tar.* | wc -l)"
else
    echo "Warning: No package files found in mirror directory"
fi

chmod +x /start.sh

echo "AUR mirror build process completed!"
