# Zig GTK4 Counter

A simple counter application built with Zig and GTK4 using direct C bindings via `@cImport`.

## Prerequisites

- **Zig 0.14.x**
- **GTK4** installed on your system

```bash
# macOS
brew install gtk4

# Ubuntu/Debian
sudo apt install libgtk-4-dev

# Fedora
sudo dnf install gtk4-devel
```

## Building

```bash
cd zig
zig build
```

## Running

```bash
zig build run
```

## Project Structure

```
zig/
├── build.zig          # Build configuration
├── build.zig.zon      # Package manifest (no external deps)
├── src/
│   └── main.zig       # Counter app using @cImport for GTK4
└── README.md
```

## How It Works

This project uses Zig's `@cImport` to directly import GTK4 C headers:

```zig
const c = @cImport({
    @cInclude("gtk/gtk.h");
});
```

This approach:
- **No external Zig dependencies** - just links the system GTK4
- **No duplicate library issues** - single linkage via pkg-config
- **Full GTK4 API access** - all C functions available directly
- **Cross-platform** - works on macOS, Linux, Windows (with GTK4 installed)

## Why @cImport Instead of zig-gobject?

The `zig-gobject` bindings provide nicer Zig-native APIs, but on macOS they cause duplicate dylib linking issues. Using `@cImport` directly:

1. Links GTK4 exactly once via pkg-config
2. Avoids complex dependency resolution
3. Works reliably on all platforms
4. Matches how Ghostty and other production apps handle GTK

## Sources

- [Learning GTK with Zig](https://medium.com/@swindlers-inc/learning-gtk-with-zig-0371bb22e865) - Tutorial on GTK + Zig
- [zig-gtk4-starter](https://github.com/bgub/zig-gtk4-starter) - Simple GTK4 + Zig example
- [Ghostty](https://github.com/ghostty-org/ghostty) - Production Zig + GTK4 terminal
