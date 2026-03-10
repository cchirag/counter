const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const app_name = "spectre";
const app_display_name = "Spectre";
const app_id = "com.spectre.app";
const app_version = "0.1.0";

pub fn main() !void {
    // Use arena allocator - everything gets freed at once at the end
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const os = builtin.os.tag;
    const arch = @tagName(builtin.cpu.arch);

    std.debug.print("=== Spectre Bundler ===\n", .{});
    std.debug.print("OS: {s}, Arch: {s}\n\n", .{ @tagName(os), arch });

    switch (os) {
        .macos => try bundleMacOS(allocator),
        .linux => try bundleLinux(allocator),
        .windows => try bundleWindows(allocator),
        else => {
            std.debug.print("Unsupported OS: {s}\n", .{@tagName(os)});
            return error.UnsupportedOS;
        },
    }
}

// =============================================================================
// macOS Bundler
// =============================================================================

fn bundleMacOS(allocator: Allocator) !void {
    const exe_path = "zig-out/bin/" ++ app_name;
    const dist_dir = "dist";
    const app_bundle = dist_dir ++ "/" ++ app_display_name ++ ".app";

    // Clean and create bundle structure
    std.debug.print("Creating app bundle structure...\n", .{});
    fs.cwd().deleteTree(dist_dir) catch {};

    try fs.cwd().makePath(app_bundle ++ "/Contents/MacOS");
    try fs.cwd().makePath(app_bundle ++ "/Contents/Frameworks");
    try fs.cwd().makePath(app_bundle ++ "/Contents/Resources/share/glib-2.0/schemas");
    try fs.cwd().makePath(app_bundle ++ "/Contents/Resources/share/icons");

    // Copy executable
    std.debug.print("Copying executable...\n", .{});
    try fs.cwd().copyFile(exe_path, fs.cwd(), app_bundle ++ "/Contents/MacOS/" ++ app_name, .{});

    // Collect and copy dylib dependencies
    std.debug.print("Collecting dependencies...\n", .{});
    var processed = std.StringHashMap(void).init(allocator);

    const deps = try getDylibDeps(allocator, exe_path);
    for (deps) |dep| {
        try copyDylibRecursive(allocator, dep, app_bundle ++ "/Contents/Frameworks", &processed);
    }

    // Fix executable references
    std.debug.print("Fixing binary references...\n", .{});
    const exe_in_bundle = app_bundle ++ "/Contents/MacOS/" ++ app_name;
    for (deps) |dep| {
        const dep_name = fs.path.basename(dep);
        const new_path = try std.fmt.allocPrintZ(allocator, "@executable_path/../Frameworks/{s}", .{dep_name});
        runCommand(allocator, &.{ "install_name_tool", "-change", dep, new_path, exe_in_bundle }) catch {};
    }
    runCommand(allocator, &.{ "install_name_tool", "-add_rpath", "@executable_path/../Frameworks", exe_in_bundle }) catch {};

    // Copy GLib schemas
    std.debug.print("Copying resources...\n", .{});
    const schema_dir = getCommandOutput(allocator, &.{ "pkg-config", "--variable=schemasdir", "gio-2.0" }) catch
        "/opt/homebrew/share/glib-2.0/schemas";
    copyGlobFiles(allocator, schema_dir, ".compiled", app_bundle ++ "/Contents/Resources/share/glib-2.0/schemas") catch {};

    // Copy icons
    const icon_base = getCommandOutput(allocator, &.{ "pkg-config", "--variable=datadir", "gtk4" }) catch
        "/opt/homebrew/share";
    const adwaita_src = try std.fmt.allocPrint(allocator, "{s}/icons/Adwaita", .{icon_base});
    const hicolor_src = try std.fmt.allocPrint(allocator, "{s}/icons/hicolor", .{icon_base});
    copyDirRecursive(allocator, adwaita_src, app_bundle ++ "/Contents/Resources/share/icons/Adwaita") catch {};
    copyDirRecursive(allocator, hicolor_src, app_bundle ++ "/Contents/Resources/share/icons/hicolor") catch {};

    // Write Info.plist
    std.debug.print("Creating Info.plist...\n", .{});
    const plist = try fs.cwd().createFile(app_bundle ++ "/Contents/Info.plist", .{});
    defer plist.close();
    try plist.writeAll(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        \\<plist version="1.0">
        \\<dict>
        \\    <key>CFBundleExecutable</key>
        \\    <string>spectre-launcher</string>
        \\    <key>CFBundleIdentifier</key>
        \\    <string>com.spectre.app</string>
        \\    <key>CFBundleName</key>
        \\    <string>Spectre</string>
        \\    <key>CFBundleDisplayName</key>
        \\    <string>Spectre</string>
        \\    <key>CFBundleVersion</key>
        \\    <string>0.1.0</string>
        \\    <key>CFBundleShortVersionString</key>
        \\    <string>0.1.0</string>
        \\    <key>CFBundlePackageType</key>
        \\    <string>APPL</string>
        \\    <key>LSMinimumSystemVersion</key>
        \\    <string>11.0</string>
        \\    <key>NSHighResolutionCapable</key>
        \\    <true/>
        \\</dict>
        \\</plist>
        \\
    );

    // Write launcher script
    const launcher = try fs.cwd().createFile(app_bundle ++ "/Contents/MacOS/spectre-launcher", .{ .mode = 0o755 });
    defer launcher.close();
    try launcher.writeAll(
        \\#!/bin/bash
        \\DIR="$(cd "$(dirname "$0")" && pwd)"
        \\CONTENTS="$(dirname "$DIR")"
        \\export DYLD_LIBRARY_PATH="$CONTENTS/Frameworks:$DYLD_LIBRARY_PATH"
        \\export XDG_DATA_DIRS="$CONTENTS/Resources/share:${XDG_DATA_DIRS:-/usr/share}"
        \\export GSETTINGS_SCHEMA_DIR="$CONTENTS/Resources/share/glib-2.0/schemas"
        \\exec "$DIR/spectre" "$@"
        \\
    );

    // Ad-hoc code sign
    std.debug.print("Code signing...\n", .{});
    runCommand(allocator, &.{ "codesign", "--force", "--deep", "--sign", "-", app_bundle }) catch {};

    std.debug.print("\n=== Bundle Complete ===\n", .{});
    std.debug.print("Output: {s}\n", .{app_bundle});
    std.debug.print("To run: open {s}\n", .{app_bundle});
}

fn getDylibDeps(allocator: Allocator, path: []const u8) ![][]const u8 {
    const output = try getCommandOutput(allocator, &.{ "otool", "-L", path });
    var deps = std.ArrayList([]const u8).init(allocator);

    var lines = mem.splitScalar(u8, output, '\n');
    _ = lines.next(); // Skip first line

    while (lines.next()) |line| {
        const trimmed = mem.trim(u8, line, " \t");
        if (trimmed.len == 0) continue;

        const end = mem.indexOf(u8, trimmed, " (") orelse trimmed.len;
        const dep_path = mem.trim(u8, trimmed[0..end], " \t");

        if (mem.startsWith(u8, dep_path, "/usr/lib")) continue;
        if (mem.startsWith(u8, dep_path, "/System")) continue;
        if (mem.startsWith(u8, dep_path, "@executable_path")) continue;
        if (mem.startsWith(u8, dep_path, "@rpath")) continue;
        if (dep_path.len == 0) continue;

        try deps.append(try allocator.dupe(u8, dep_path));
    }

    return deps.toOwnedSlice();
}

fn copyDylibRecursive(allocator: Allocator, src_path: []const u8, dest_dir: []const u8, processed: *std.StringHashMap(void)) !void {
    const name = fs.path.basename(src_path);

    if (processed.contains(name)) return;
    try processed.put(try allocator.dupe(u8, name), {});

    fs.cwd().access(src_path, .{}) catch return;

    std.debug.print("  Copying: {s}\n", .{name});

    const dest_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_dir, name });
    fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch return;

    const rpath_name = try std.fmt.allocPrintZ(allocator, "@rpath/{s}", .{name});
    runCommand(allocator, &.{ "install_name_tool", "-id", rpath_name, dest_path }) catch {};

    const deps = getDylibDeps(allocator, src_path) catch return;
    for (deps) |dep| {
        const dep_name = fs.path.basename(dep);
        const new_ref = try std.fmt.allocPrintZ(allocator, "@rpath/{s}", .{dep_name});
        runCommand(allocator, &.{ "install_name_tool", "-change", dep, new_ref, dest_path }) catch {};
        try copyDylibRecursive(allocator, dep, dest_dir, processed);
    }
}

// =============================================================================
// Linux Bundler
// =============================================================================

fn bundleLinux(allocator: Allocator) !void {
    const exe_path = "zig-out/bin/" ++ app_name;
    const dist_dir = "dist";

    std.debug.print("Creating bundle structure...\n", .{});
    fs.cwd().deleteTree(dist_dir) catch {};

    try fs.cwd().makePath(dist_dir ++ "/lib");
    try fs.cwd().makePath(dist_dir ++ "/share/glib-2.0/schemas");
    try fs.cwd().makePath(dist_dir ++ "/share/icons");
    try fs.cwd().makePath(dist_dir ++ "/share/applications");

    std.debug.print("Copying executable...\n", .{});
    try fs.cwd().copyFile(exe_path, fs.cwd(), dist_dir ++ "/" ++ app_name, .{});

    std.debug.print("Collecting dependencies...\n", .{});
    var processed = std.StringHashMap(void).init(allocator);
    try copyLinuxLibsRecursive(allocator, exe_path, dist_dir ++ "/lib", &processed);

    std.debug.print("Setting RPATH...\n", .{});
    runCommand(allocator, &.{ "patchelf", "--set-rpath", "$ORIGIN/lib", dist_dir ++ "/" ++ app_name }) catch {
        std.debug.print("  patchelf not available, skipping RPATH\n", .{});
    };

    std.debug.print("Copying resources...\n", .{});
    copyGlobFiles(allocator, "/usr/share/glib-2.0/schemas", ".compiled", dist_dir ++ "/share/glib-2.0/schemas") catch {};
    copyDirRecursive(allocator, "/usr/share/icons/Adwaita", dist_dir ++ "/share/icons/Adwaita") catch {};
    copyDirRecursive(allocator, "/usr/share/icons/hicolor", dist_dir ++ "/share/icons/hicolor") catch {};

    const desktop = try fs.cwd().createFile(dist_dir ++ "/share/applications/spectre.desktop", .{});
    defer desktop.close();
    try desktop.writeAll(
        \\[Desktop Entry]
        \\Name=Spectre
        \\Comment=Binary Protocol Builder
        \\Exec=spectre
        \\Icon=spectre
        \\Type=Application
        \\Categories=Development;Utility;
        \\
    );

    const launcher = try fs.cwd().createFile(dist_dir ++ "/run.sh", .{ .mode = 0o755 });
    defer launcher.close();
    try launcher.writeAll(
        \\#!/bin/bash
        \\SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        \\export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"
        \\export XDG_DATA_DIRS="$SCRIPT_DIR/share:${XDG_DATA_DIRS:-/usr/share}"
        \\export GSETTINGS_SCHEMA_DIR="$SCRIPT_DIR/share/glib-2.0/schemas"
        \\exec "$SCRIPT_DIR/spectre" "$@"
        \\
    );

    std.debug.print("\n=== Bundle Complete ===\n", .{});
    std.debug.print("Output: {s}/\n", .{dist_dir});
    std.debug.print("To run: ./{s}/run.sh\n", .{dist_dir});
}

fn copyLinuxLibsRecursive(allocator: Allocator, binary_path: []const u8, dest_dir: []const u8, processed: *std.StringHashMap(void)) !void {
    const output = getCommandOutput(allocator, &.{ "ldd", binary_path }) catch return;

    var lines = mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        const arrow_pos = mem.indexOf(u8, line, " => ") orelse continue;
        const rest = line[arrow_pos + 4 ..];
        const space_pos = mem.indexOf(u8, rest, " ") orelse rest.len;
        const lib_path = mem.trim(u8, rest[0..space_pos], " \t");

        if (lib_path.len == 0) continue;
        if (mem.startsWith(u8, lib_path, "/lib")) continue;
        if (mem.startsWith(u8, lib_path, "/lib64")) continue;
        if (mem.indexOf(u8, lib_path, "linux-vdso") != null) continue;

        const name = fs.path.basename(lib_path);
        if (processed.contains(name)) continue;
        try processed.put(try allocator.dupe(u8, name), {});

        std.debug.print("  Copying: {s}\n", .{name});

        const dest_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_dir, name });
        fs.cwd().copyFile(lib_path, fs.cwd(), dest_path, .{}) catch continue;
        try copyLinuxLibsRecursive(allocator, lib_path, dest_dir, processed);
    }
}

// =============================================================================
// Windows Bundler
// =============================================================================

fn bundleWindows(allocator: Allocator) !void {
    const exe_path = "zig-out/bin/" ++ app_name ++ ".exe";
    const dist_dir = "dist";
    const mingw_prefix = "/ucrt64";

    std.debug.print("Creating bundle structure...\n", .{});
    fs.cwd().deleteTree(dist_dir) catch {};

    try fs.cwd().makePath(dist_dir ++ "/bin");
    try fs.cwd().makePath(dist_dir ++ "/share/glib-2.0/schemas");
    try fs.cwd().makePath(dist_dir ++ "/share/icons");

    std.debug.print("Copying executable...\n", .{});
    try fs.cwd().copyFile(exe_path, fs.cwd(), dist_dir ++ "/bin/" ++ app_name ++ ".exe", .{});

    std.debug.print("Collecting dependencies...\n", .{});
    var processed = std.StringHashMap(void).init(allocator);
    try copyWindowsDllsRecursive(allocator, dist_dir ++ "/bin/" ++ app_name ++ ".exe", dist_dir ++ "/bin", mingw_prefix, &processed);

    std.debug.print("Copying resources...\n", .{});
    copyGlobFiles(allocator, mingw_prefix ++ "/share/glib-2.0/schemas", ".compiled", dist_dir ++ "/share/glib-2.0/schemas") catch {};
    copyDirRecursive(allocator, mingw_prefix ++ "/share/icons/Adwaita", dist_dir ++ "/share/icons/Adwaita") catch {};
    copyDirRecursive(allocator, mingw_prefix ++ "/share/icons/hicolor", dist_dir ++ "/share/icons/hicolor") catch {};

    const launcher = try fs.cwd().createFile(dist_dir ++ "/Spectre.bat", .{});
    defer launcher.close();
    try launcher.writeAll(
        \\@echo off
        \\cd /d "%~dp0"
        \\set PATH=%~dp0bin;%PATH%
        \\set XDG_DATA_DIRS=%~dp0share
        \\set GSETTINGS_SCHEMA_DIR=%~dp0share\glib-2.0\schemas
        \\start "" "%~dp0bin\spectre.exe" %*
        \\
    );

    std.debug.print("\n=== Bundle Complete ===\n", .{});
    std.debug.print("Output: {s}/\n", .{dist_dir});
    std.debug.print("To run: {s}/Spectre.bat\n", .{dist_dir});
}

fn copyWindowsDllsRecursive(allocator: Allocator, binary_path: []const u8, dest_dir: []const u8, mingw_prefix: []const u8, processed: *std.StringHashMap(void)) !void {
    const output = getCommandOutput(allocator, &.{ "objdump", "-p", binary_path }) catch return;

    var lines = mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        const prefix = "DLL Name: ";
        const idx = mem.indexOf(u8, line, prefix) orelse continue;
        const dll_name = mem.trim(u8, line[idx + prefix.len ..], " \t\r");

        if (dll_name.len == 0) continue;

        var lower_buf: [256]u8 = undefined;
        const lower_name = std.ascii.lowerString(&lower_buf, dll_name);

        if (isWindowsSystemDll(lower_name)) continue;
        if (processed.contains(lower_name)) continue;
        try processed.put(try allocator.dupe(u8, lower_name), {});

        const bin_path = try std.fmt.allocPrint(allocator, "{s}/bin/{s}", .{ mingw_prefix, dll_name });
        const lib_path = try std.fmt.allocPrint(allocator, "{s}/lib/{s}", .{ mingw_prefix, dll_name });

        const src_path = if (fs.cwd().access(bin_path, .{})) |_| bin_path else |_| if (fs.cwd().access(lib_path, .{})) |_| lib_path else |_| continue;

        std.debug.print("  Copying: {s}\n", .{dll_name});

        const dest_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_dir, dll_name });
        fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch continue;
        try copyWindowsDllsRecursive(allocator, src_path, dest_dir, mingw_prefix, processed);
    }
}

fn isWindowsSystemDll(name: []const u8) bool {
    const system_dlls = [_][]const u8{
        "kernel32.dll",  "user32.dll",    "gdi32.dll",     "shell32.dll",
        "ole32.dll",     "oleaut32.dll",  "advapi32.dll",  "msvcrt.dll",
        "ws2_32.dll",    "ntdll.dll",     "comctl32.dll",  "comdlg32.dll",
        "imm32.dll",     "winmm.dll",     "version.dll",   "shlwapi.dll",
        "crypt32.dll",   "bcrypt.dll",    "secur32.dll",   "netapi32.dll",
        "userenv.dll",   "winspool.drv",  "dwmapi.dll",    "uxtheme.dll",
        "dnsapi.dll",    "iphlpapi.dll",  "setupapi.dll",  "cfgmgr32.dll",
        "powrprof.dll",  "ucrtbase.dll",
    };

    for (system_dlls) |sys| {
        if (mem.eql(u8, name, sys)) return true;
    }

    return mem.startsWith(u8, name, "api-ms-") or mem.startsWith(u8, name, "ext-ms-");
}

// =============================================================================
// Utility Functions
// =============================================================================

fn runCommand(allocator: Allocator, argv: []const []const u8) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stderr_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    _ = try child.spawnAndWait();
}

fn getCommandOutput(allocator: Allocator, argv: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });

    if (result.term.Exited != 0) {
        return error.CommandFailed;
    }

    return mem.trim(u8, result.stdout, " \t\n\r");
}

fn copyGlobFiles(allocator: Allocator, src_dir: []const u8, suffix: []const u8, dest_dir: []const u8) !void {
    var dir = fs.cwd().openDir(src_dir, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!mem.endsWith(u8, entry.name, suffix)) continue;

        const src_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ src_dir, entry.name });
        const dest_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_dir, entry.name });
        fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch {};
    }
}

fn copyDirRecursive(allocator: Allocator, src_dir: []const u8, dest_dir: []const u8) !void {
    fs.cwd().makePath(dest_dir) catch {};

    var dir = fs.cwd().openDir(src_dir, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const src_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ src_dir, entry.name });
        const dest_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dest_dir, entry.name });

        switch (entry.kind) {
            .file => fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch {},
            .directory => try copyDirRecursive(allocator, src_path, dest_path),
            else => {},
        }
    }
}
