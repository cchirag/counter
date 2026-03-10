const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gtk-counter",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("gtk4");

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the counter application");
    run_step.dependOn(&run_cmd.step);

    // Bundle step - creates portable distribution
    const bundle_step = b.step("bundle", "Create portable bundle with all dependencies");
    const bundle_script = b.addSystemCommand(&.{
        "/bin/bash",
        "scripts/bundle.sh",
    });
    bundle_script.step.dependOn(b.getInstallStep());
    bundle_step.dependOn(&bundle_script.step);
}
