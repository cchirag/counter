const std = @import("std");
const builtin = @import("builtin");

const app_name = "spectre";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = app_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    if (target.result.os.tag == .windows) {
        exe.addLibraryPath(.{ .cwd_relative = "C:/msys64/ucrt64/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "D:/a/_temp/msys64/ucrt64/lib" });
    }

    exe.linkSystemLibrary("libadwaita-1");

    b.installArtifact(exe);

    // === Run step ===
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // === Prod step: release build + bundle ===
    const prod_step = b.step("prod", "Build optimized release and create distributable bundle");

    // Build release executable
    const prod_exe = b.addExecutable(.{
        .name = app_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    prod_exe.linkLibC();
    if (target.result.os.tag == .windows) {
        prod_exe.addLibraryPath(.{ .cwd_relative = "C:/msys64/ucrt64/lib" });
        prod_exe.addLibraryPath(.{ .cwd_relative = "D:/a/_temp/msys64/ucrt64/lib" });
    }
    prod_exe.linkSystemLibrary("libadwaita-1");

    const install_prod = b.addInstallArtifact(prod_exe, .{});
    prod_step.dependOn(&install_prod.step);

    // Build and run bundler (runs on host machine)
    const bundler = b.addExecutable(.{
        .name = "bundler",
        .root_source_file = b.path("src/bundler.zig"),
        .target = b.graph.host,
    });

    const run_bundler = b.addRunArtifact(bundler);
    run_bundler.step.dependOn(&install_prod.step);
    prod_step.dependOn(&run_bundler.step);

    // === Bundle step (just bundling, assumes build exists) ===
    const bundle_step = b.step("bundle", "Create bundle from existing build");
    const bundle_only = b.addRunArtifact(bundler);
    bundle_step.dependOn(&bundle_only.step);
}
