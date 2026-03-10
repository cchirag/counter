#!/usr/bin/env bash
# Bundle GTK4/libadwaita application with all dependencies for portable distribution
set -e

APP_NAME="gtk-counter"
BUNDLE_DIR="bundle"
EXE_PATH="zig-out/bin/$APP_NAME"

echo "=== GTK4 Application Bundler ==="
echo ""

# Check if executable exists
if [ ! -f "$EXE_PATH" ]; then
    echo "Error: Executable not found at $EXE_PATH"
    echo "Run 'zig build -Doptimize=ReleaseFast' first"
    exit 1
fi

# Detect OS
OS="$(uname -s)"
echo "Detected OS: $OS"

# Clean and create bundle directory
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/lib"
mkdir -p "$BUNDLE_DIR/share/glib-2.0/schemas"
mkdir -p "$BUNDLE_DIR/share/icons"
mkdir -p "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders"

# Copy executable
cp "$EXE_PATH" "$BUNDLE_DIR/"
echo "Copied executable"

# File to track processed libraries (avoid associative arrays for bash 3 compat)
PROCESSED_FILE=$(mktemp)
trap "rm -f $PROCESSED_FILE" EXIT

is_processed() {
    grep -q "^$1$" "$PROCESSED_FILE" 2>/dev/null
}

mark_processed() {
    echo "$1" >> "$PROCESSED_FILE"
}

case "$OS" in
    Darwin)
        echo ""
        echo "=== Bundling for macOS ==="

        # Function to get non-system dylib dependencies
        get_deps() {
            otool -L "$1" 2>/dev/null | tail -n +2 | awk '{print $1}' | \
                grep -v "^/usr/lib" | \
                grep -v "^/System" | \
                grep -v "@executable_path" | \
                grep -v "@rpath" || true
        }

        # Function to copy and fix a dylib
        copy_and_fix_dylib() {
            local src="$1"
            local name=$(basename "$src")
            local dest="$BUNDLE_DIR/lib/$name"

            # Skip if already processed
            if is_processed "$name"; then
                return 0
            fi
            mark_processed "$name"

            # Skip if source doesn't exist
            if [ ! -f "$src" ]; then
                echo "  Warning: $src not found, skipping"
                return 0
            fi

            echo "  Copying: $name"
            cp "$src" "$dest"
            chmod 755 "$dest"

            # Change install name to use @rpath
            install_name_tool -id "@rpath/$name" "$dest" 2>/dev/null || true

            # Process dependencies of this library
            local deps=$(get_deps "$src")
            for dep in $deps; do
                local dep_name=$(basename "$dep")
                # Fix reference in current library
                install_name_tool -change "$dep" "@rpath/$dep_name" "$dest" 2>/dev/null || true
                # Recursively copy dependency
                copy_and_fix_dylib "$dep"
            done
        }

        # Get and process all dependencies
        echo "Collecting dependencies..."
        DEPS=$(get_deps "$BUNDLE_DIR/$APP_NAME")
        for dep in $DEPS; do
            copy_and_fix_dylib "$dep"
        done

        # Fix references in main executable
        echo "Fixing executable references..."
        for dep in $DEPS; do
            dep_name=$(basename "$dep")
            install_name_tool -change "$dep" "@executable_path/lib/$dep_name" "$BUNDLE_DIR/$APP_NAME" 2>/dev/null || true
        done

        # Add rpath to executable
        install_name_tool -add_rpath "@executable_path/lib" "$BUNDLE_DIR/$APP_NAME" 2>/dev/null || true

        # Copy GLib schemas
        echo "Copying GLib schemas..."
        SCHEMA_DIR=$(pkg-config --variable=schemasdir gio-2.0 2>/dev/null || echo "/opt/homebrew/share/glib-2.0/schemas")
        if [ -d "$SCHEMA_DIR" ]; then
            cp "$SCHEMA_DIR"/*.compiled "$BUNDLE_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
            cp "$SCHEMA_DIR"/*.xml "$BUNDLE_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
        fi

        # Copy icons
        echo "Copying icons..."
        ICON_BASE=$(pkg-config --variable=datadir gtk4 2>/dev/null || echo "/opt/homebrew/share")
        for icon_dir in "$ICON_BASE/icons/Adwaita" "$ICON_BASE/icons/hicolor"; do
            if [ -d "$icon_dir" ]; then
                cp -r "$icon_dir" "$BUNDLE_DIR/share/icons/" 2>/dev/null || true
            fi
        done

        # Copy GDK-Pixbuf loaders
        echo "Copying GDK-Pixbuf loaders..."
        PIXBUF_DIR=$(pkg-config --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0 2>/dev/null || echo "")
        if [ -n "$PIXBUF_DIR" ] && [ -d "$PIXBUF_DIR" ]; then
            cp "$PIXBUF_DIR"/*.so "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders/" 2>/dev/null || true
        fi

        # Create launcher script
        cat > "$BUNDLE_DIR/run.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DYLD_LIBRARY_PATH="$SCRIPT_DIR/lib:$DYLD_LIBRARY_PATH"
export XDG_DATA_DIRS="$SCRIPT_DIR/share:${XDG_DATA_DIRS:-/usr/share}"
export GSETTINGS_SCHEMA_DIR="$SCRIPT_DIR/share/glib-2.0/schemas"
export GDK_PIXBUF_MODULE_FILE="$SCRIPT_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
exec "$SCRIPT_DIR/gtk-counter" "$@"
LAUNCHER
        chmod +x "$BUNDLE_DIR/run.sh"

        # Generate pixbuf loader cache
        if command -v gdk-pixbuf-query-loaders &>/dev/null; then
            echo "Generating pixbuf loader cache..."
            GDK_PIXBUF_MODULEDIR="$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders" \
                gdk-pixbuf-query-loaders > "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null || true
        fi
        ;;

    Linux)
        echo ""
        echo "=== Bundling for Linux ==="

        # Function to get non-system library dependencies
        get_deps() {
            ldd "$1" 2>/dev/null | grep "=>" | awk '{print $3}' | \
                grep -v "^$" | \
                grep -v "^/lib" | \
                grep -v "^/lib64" | \
                grep -v "linux-vdso" || true
        }

        # Function to copy a library
        copy_lib() {
            local src="$1"
            local name=$(basename "$src")

            if is_processed "$name"; then
                return 0
            fi
            mark_processed "$name"

            if [ ! -f "$src" ]; then
                return 0
            fi

            echo "  Copying: $name"
            cp "$src" "$BUNDLE_DIR/lib/"

            # Recursively copy dependencies
            local deps=$(get_deps "$src")
            for dep in $deps; do
                copy_lib "$dep"
            done
        }

        # Copy all dependencies
        echo "Collecting dependencies..."
        DEPS=$(get_deps "$BUNDLE_DIR/$APP_NAME")
        for dep in $DEPS; do
            copy_lib "$dep"
        done

        # Set RPATH using patchelf if available
        if command -v patchelf &>/dev/null; then
            echo "Setting RPATH..."
            patchelf --set-rpath '$ORIGIN/lib' "$BUNDLE_DIR/$APP_NAME"
        fi

        # Copy GLib schemas
        echo "Copying GLib schemas..."
        SCHEMA_DIR="/usr/share/glib-2.0/schemas"
        if [ -d "$SCHEMA_DIR" ]; then
            cp "$SCHEMA_DIR"/*.compiled "$BUNDLE_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
        fi

        # Copy icons
        echo "Copying icons..."
        for icon_dir in /usr/share/icons/Adwaita /usr/share/icons/hicolor; do
            if [ -d "$icon_dir" ]; then
                cp -r "$icon_dir" "$BUNDLE_DIR/share/icons/" 2>/dev/null || true
            fi
        done

        # Create launcher script
        cat > "$BUNDLE_DIR/run.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"
export XDG_DATA_DIRS="$SCRIPT_DIR/share:${XDG_DATA_DIRS:-/usr/share}"
export GSETTINGS_SCHEMA_DIR="$SCRIPT_DIR/share/glib-2.0/schemas"
export GDK_PIXBUF_MODULE_FILE="$SCRIPT_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
exec "$SCRIPT_DIR/gtk-counter" "$@"
LAUNCHER
        chmod +x "$BUNDLE_DIR/run.sh"
        ;;

    *)
        echo "Error: Unsupported OS: $OS"
        echo "Supported: Darwin (macOS), Linux"
        exit 1
        ;;
esac

echo ""
echo "=== Bundle Complete ==="
echo ""
echo "Bundle location: $BUNDLE_DIR/"
echo ""
echo "Contents:"
ls -la "$BUNDLE_DIR/"
echo ""
echo "Libraries bundled:"
ls "$BUNDLE_DIR/lib/" | wc -l | xargs echo "  Total:"
echo ""
echo "To run the bundled application:"
echo "  ./$BUNDLE_DIR/run.sh"
echo ""
echo "To distribute:"
OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
echo "  tar -czvf $APP_NAME-$OS_LOWER.tar.gz $BUNDLE_DIR/"
