const std = @import("std");
const testing = std.testing;
const schema = @import("core").config.schema;
const helpers = @import("helpers");

test "config schema tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "Config Schema");
    defer suite.deinit();

    // File mapping test
    try suite.runTest("file_mapping", struct {
        fn run() !void {
            const mapping = schema.FileMapping{};
            try testing.expectEqualStrings("", mapping.source);
            try testing.expectEqualStrings("", mapping.target);
            try testing.expect(!mapping.executable);
        }
    }.run);

    // Module config test
    try suite.runTest("module_config", struct {
        fn run() !void {
            var config = schema.ModuleConfig{
                .name = "test",
                .namespace = "test",
                .category = "test",
            };
            try config.validate();
        }
    }.run);

    // Source inference test
    try suite.runTest("source inference", struct {
        fn run() !void {
            // Test git source inference
            var git_source = schema.Source{
                .url = "https://github.com/example/repo.git",
            };
            try testing.expectEqual(git_source.inferType(), .git);
            try git_source.validate();

            // Test path source inference
            var path_source = schema.Source{
                .location = "./local/path",
            };
            try testing.expectEqual(path_source.inferType(), .path);
            try path_source.validate();

            // Test module source inference
            const module_config = schema.ModuleConfig{
                .name = "test_module",
                .namespace = "test",
                .category = "test",
            };

            var module_source = schema.Source{
                .module = module_config,
            };
            try testing.expectEqual(module_source.inferType(), .module);
            try module_source.validate();
        }
    }.run);

    // Global config test
    try suite.runTest("global_config", struct {
        fn run() !void {
            var sources = [_]schema.Source{
                .{
                    .url = "https://github.com/example/repo1.git",
                    .enable = true,
                },
                .{
                    .url = "https://github.com/example/repo2.git",
                    .enable = true,
                },
            };

            const sources_slice = sources[0..];

            var module_entries = [_]schema.GlobalConfig.ModuleEntry{
                .{
                    .name = "test_module",
                    .sources = sources_slice,
                },
            };

            const modules_slice = module_entries[0..];

            var config = schema.GlobalConfig{
                .name = "test",
                .namespace = "test",
                .modules = modules_slice,
            };

            try config.validate();
        }
    }.run);

    // Print test results
    suite.printResults();
}

// Optional: Add helper function for debugging output
fn printConfigDetails(config: anytype) void {
    const T = @TypeOf(config);
    const type_info = @typeInfo(T);

    switch (type_info) {
        .Struct => |info| {
            std.debug.print("\n{s} Details:\n", .{@typeName(T)});
            inline for (info.fields) |field| {
                const value = @field(config, field.name);
                switch (@TypeOf(value)) {
                    []const u8 => std.debug.print("  {s}: {s}\n", .{ field.name, value }),
                    bool => std.debug.print("  {s}: {}\n", .{ field.name, value }),
                    else => {}, // Skip other types
                }
            }
        },
        else => {},
    }
}
