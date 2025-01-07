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

    // Add version options
    exe.root_module.addOptions("version", version_options);

    // Add toml dependency
    const toml_dep = b.dependency("zig-toml", .{});
    const toml_module = toml_dep.module("zig-toml");
    exe.root_module.addImport("toml", toml_module);

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
    // Create a test step that will run all tests
    const test_step = b.step("test", "Run all tests");

    // Add all test files here
    const test_files = [_][]const u8{
        "src/main.zig",
        "tests/core/config_test.zig",
        "tests/core/zig-toml_test.zig",
        "tests/core/parser_test.zig",
    };

    // Create toml dependency once
    const toml_dep = b.dependency("zig-toml", .{});
    const toml_module = toml_dep.module("zig-toml");

    // Create core module with toml dependency
    const core_module = b.createModule(.{
        .root_source_file = b.path("src/core.zig"),
        .imports = &.{
            .{ .name = "toml", .module = toml_module },
        },
    });

    // Create and configure each test artifact
    for (test_files) |test_file| {
        // Extract just the filename without path and extension
        const basename = std.fs.path.basename(test_file);
        const name = b.fmt("test_{s}", .{basename[0 .. basename.len - 4]}); // Remove .zig extension

        const test_artifact = b.addTest(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
            .name = name,
        });

        // Add required dependencies
        test_artifact.root_module.addImport("core", core_module);
        test_artifact.root_module.addImport("toml", toml_module);

        // Create run step for this test
        const run_test = b.addRunArtifact(test_artifact);

        // Make test output visible
        run_test.has_side_effects = true;

        // Add to main test step
        test_step.dependOn(&run_test.step);
    }
}

fn getVersion(b: *std.Build) ![]const u8 {
    const zon_contents = try std.fs.cwd().readFileAlloc(b.allocator, "build.zig.zon", 1024 * 1024);
    defer b.allocator.free(zon_contents);

    var i: usize = 0;
    while (i < zon_contents.len) : (i += 1) {
        if (std.mem.startsWith(u8, zon_contents[i..], ".version")) {
            while (i < zon_contents.len) : (i += 1) {
                if (zon_contents[i] == '"') {
                    i += 1;
                    const version_start = i;
                    while (i < zon_contents.len and zon_contents[i] != '"') : (i += 1) {}
                    return b.allocator.dupe(u8, zon_contents[version_start..i]);
                }
            }
        }
    }

    return error.VersionNotFound;
}
