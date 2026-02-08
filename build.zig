const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "STATE_PATH", (b.option([]const u8, "state_path", "Path to the state file") orelse "state.json"));

    root_module.addIncludePath(b.path("thirdparty/raylib-5.5_linux_amd64/include/"));
    root_module.addIncludePath(b.path("thirdparty/"));
    root_module.addLibraryPath(b.path("thirdparty/raylib-5.5_linux_amd64/lib/"));
    root_module.linkSystemLibrary("raylib", .{});
    root_module.addOptions("config", options);

    const exe = b.addExecutable(.{
        .name = "d_kaizen",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
