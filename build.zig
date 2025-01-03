const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create version options
    const version_options = createVersionOptions(b) catch |err| {
        std.debug.print("Failed to read version: {}\n", .{err});
        std.process.exit(1);
    };

    // Create executable
    const exe = createExecutable(b, target, optimize, version_options);
    b.installArtifact(exe);

    // Create run step
    createRunStep(b, exe);

    // Create test step
    createTestStep(b, target, optimize);
}

fn createVersionOptions(b: *std.Build) !*std.Build.Step.Options {
    // Allows version to be overridden via CLI arg, otherwise reads from build.zig.zon
    const version = b.option([]const u8, "version", "Program version") orelse
        try getVersion(b);

    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    return options;
}

fn createExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    version_options: *std.Build.Step.Options,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "dotkit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addOptions("version", version_options);
    return exe;
}

fn createRunStep(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run dotkit");
    run_step.dependOn(&run_cmd.step);
}

fn createTestStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn getVersion(b: *std.Build) ![]const u8 {
    // Extracts version string from build.zig.zon file
    // Format expected: .version = "x.y.z"
    const zon_contents = try std.fs.cwd().readFileAlloc(b.allocator, "build.zig.zon", 1024 * 1024);
    defer b.allocator.free(zon_contents);

    var i: usize = 0;
    while (i < zon_contents.len) : (i += 1) {
        if (std.mem.startsWith(u8, zon_contents[i..], ".version")) {
            // Extract version value between quotes
            while (i < zon_contents.len) : (i += 1) {
                if (zon_contents[i] == '"') {
                    i += 1;
                    const version_start = i;
                    while (i < zon_contents.len and zon_contents[i] != '"') : (i += 1) {}
                    return b.dupe(zon_contents[version_start..i]);
                }
            }
        }
    }

    return error.VersionNotFound;
}
