#!/bin/bash
# Bundle GTK4 application with all dependencies for Windows (MSYS2/UCRT64)
set -e

APP_NAME="gtk-counter"
BUNDLE_DIR="bundle"
EXE_PATH="zig-out/bin/$APP_NAME.exe"
MINGW_PREFIX="/ucrt64"

echo "=== GTK4 Windows Bundler (MSYS2/UCRT64) ==="
echo ""

# Check if executable exists
if [ ! -f "$EXE_PATH" ]; then
    echo "Error: Executable not found at $EXE_PATH"
    echo "Run 'zig build -Doptimize=ReleaseFast' first"
    exit 1
fi

# Clean and create bundle directory
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/bin"
mkdir -p "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders"
mkdir -p "$BUNDLE_DIR/share/glib-2.0/schemas"
mkdir -p "$BUNDLE_DIR/share/icons"

# Copy executable
cp "$EXE_PATH" "$BUNDLE_DIR/bin/"
echo "Copied executable"

# Track processed DLLs
PROCESSED_FILE=$(mktemp)
trap "rm -f $PROCESSED_FILE" EXIT

is_processed() {
    grep -q "^$1$" "$PROCESSED_FILE" 2>/dev/null
}

mark_processed() {
    echo "$1" >> "$PROCESSED_FILE"
}

# Function to get DLL dependencies
get_deps() {
    objdump -p "$1" 2>/dev/null | grep "DLL Name:" | awk '{print $3}' || true
}

# Function to find and copy a DLL
copy_dll() {
    local name="$1"
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

    # Skip if already processed
    if is_processed "$name_lower"; then
        return 0
    fi
    mark_processed "$name_lower"

    # Skip Windows system DLLs
    case "$name_lower" in
        kernel32.dll|user32.dll|gdi32.dll|shell32.dll|ole32.dll|oleaut32.dll|\
        advapi32.dll|msvcrt.dll|ws2_32.dll|ntdll.dll|comctl32.dll|comdlg32.dll|\
        imm32.dll|winmm.dll|version.dll|shlwapi.dll|crypt32.dll|bcrypt.dll|\
        secur32.dll|netapi32.dll|userenv.dll|winspool.drv|dwmapi.dll|uxtheme.dll|\
        dnsapi.dll|iphlpapi.dll|setupapi.dll|cfgmgr32.dll|powrprof.dll|\
        api-ms-*.dll|ext-ms-*.dll|ucrtbase.dll)
            return 0
            ;;
    esac

    # Find the DLL in MSYS2 paths
    local src=""
    for dir in "$MINGW_PREFIX/bin" "$MINGW_PREFIX/lib"; do
        if [ -f "$dir/$name" ]; then
            src="$dir/$name"
            break
        fi
    done

    if [ -z "$src" ]; then
        echo "  Warning: $name not found, skipping"
        return 0
    fi

    echo "  Copying: $name"
    cp "$src" "$BUNDLE_DIR/bin/"

    # Recursively copy dependencies
    local deps=$(get_deps "$src")
    for dep in $deps; do
        copy_dll "$dep"
    done
}

# Copy all dependencies of the executable
echo "Collecting dependencies..."
DEPS=$(get_deps "$BUNDLE_DIR/bin/$APP_NAME.exe")
for dep in $DEPS; do
    copy_dll "$dep"
done

# Copy GLib schemas
echo "Copying GLib schemas..."
if [ -d "$MINGW_PREFIX/share/glib-2.0/schemas" ]; then
    cp "$MINGW_PREFIX/share/glib-2.0/schemas/"*.compiled "$BUNDLE_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
fi

# Copy icons
echo "Copying icons..."
for icon_theme in Adwaita hicolor; do
    if [ -d "$MINGW_PREFIX/share/icons/$icon_theme" ]; then
        cp -r "$MINGW_PREFIX/share/icons/$icon_theme" "$BUNDLE_DIR/share/icons/" 2>/dev/null || true
    fi
done

# Copy GDK-Pixbuf loaders
echo "Copying GDK-Pixbuf loaders..."
PIXBUF_DIR="$MINGW_PREFIX/lib/gdk-pixbuf-2.0/2.10.0/loaders"
if [ -d "$PIXBUF_DIR" ]; then
    cp "$PIXBUF_DIR/"*.dll "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders/" 2>/dev/null || true

    # Generate loaders cache with correct paths
    GDK_PIXBUF_MODULEDIR="$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders" \
        gdk-pixbuf-query-loaders > "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null || true

    # Fix paths in cache to be relative
    sed -i 's|.*/lib/|lib/|g' "$BUNDLE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" 2>/dev/null || true
fi

# Copy GTK settings
mkdir -p "$BUNDLE_DIR/etc/gtk-4.0"
cat > "$BUNDLE_DIR/etc/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Windows10
gtk-icon-theme-name=Adwaita
gtk-font-name=Segoe UI 10
EOF

# Create launcher batch file
cat > "$BUNDLE_DIR/run.bat" << 'LAUNCHER'
@echo off
cd /d "%~dp0"
set PATH=%~dp0bin;%PATH%
set XDG_DATA_DIRS=%~dp0share
set GSETTINGS_SCHEMA_DIR=%~dp0share\glib-2.0\schemas
set GDK_PIXBUF_MODULE_FILE=%~dp0lib\gdk-pixbuf-2.0\2.10.0\loaders.cache
start "" "%~dp0bin\gtk-counter.exe" %*
LAUNCHER

echo ""
echo "=== Bundle Complete ==="
echo ""
echo "Bundle location: $BUNDLE_DIR/"
echo ""
echo "Contents:"
ls -la "$BUNDLE_DIR/"
echo ""
echo "DLLs bundled:"
ls "$BUNDLE_DIR/bin/"*.dll 2>/dev/null | wc -l | xargs echo "  Total:"
echo ""
echo "To run the bundled application:"
echo "  $BUNDLE_DIR/run.bat"
echo ""
echo "To distribute:"
echo "  zip -r $APP_NAME-windows.zip $BUNDLE_DIR/"
