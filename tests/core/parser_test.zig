const std = @import("std");
const testing = std.testing;
const config = @import("core").config;
const helpers = @import("helpers");

test "config parser tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "Config Parser");
    defer suite.deinit();

    // Module config loading test
    try suite.runTest("load module config", struct {
        fn run() !void {
            var module_config = try config.parser.loadModuleConfig(testing.allocator, "tests/fixtures/module.toml");
            defer module_config.deinit(testing.allocator);

            try testing.expectEqualStrings("test-module", module_config.name);
            try testing.expectEqualStrings("test", module_config.namespace);
            try testing.expectEqualStrings("testing", module_config.category);

            if (module_config.description) |desc| {
                try testing.expectEqualStrings("A test module", desc);
            }

            // Verify files array
            try testing.expect(module_config.files.len == 1);
            const file = module_config.files[0];
            try testing.expectEqualStrings("src/test", file.source);
            try testing.expectEqualStrings("~/.config/test", file.target);
        }
    }.run);

    // Invalid file test
    try suite.runTest("invalid file handling", struct {
        fn run() !void {
            try testing.expectError(error.FileNotFound, config.parser.loadModuleConfig(testing.allocator, "nonexistent.toml"));
        }
    }.run);

    // Global config loading test
    try suite.runTest("load global config", struct {
        fn run() !void {
            var global_config = try config.parser.loadGlobalConfig(testing.allocator, "tests/fixtures/global.toml");
            defer global_config.deinit(testing.allocator);

            try testing.expectEqualStrings("test-global", global_config.namespace);

            if (global_config.name) |name| {
                try testing.expectEqualStrings("test-config", name);
            }

            if (global_config.description) |desc| {
                try testing.expectEqualStrings("A test global config", desc);
            }

            if (global_config.backup_path) |path| {
                try testing.expectEqualStrings("~/.backup", path);
            }

            // Verify modules
            try testing.expect(global_config.modules.len == 1);
            const module = global_config.modules[0];
            try testing.expectEqualStrings("core", module.name);

            // Verify sources
            try testing.expect(module.sources.len == 1);
            const source = module.sources[0];
            if (source.url) |url| {
                try testing.expectEqualStrings("https://github.com/example/core.git", url);
            }
            try testing.expect(source.enable);
        }
    }.run);

    // Invalid global config file test
    try suite.runTest("invalid global file handling", struct {
        fn run() !void {
            try testing.expectError(error.FileNotFound, config.parser.loadGlobalConfig(testing.allocator, "nonexistent.toml"));
        }
    }.run);

    // Print test results
    suite.printResults();
}

// Helper function to print parsed config details for debugging
fn printParsedConfig(cfg: anytype) void {
    const T = @TypeOf(cfg);
    const type_info = @typeInfo(T);

    switch (type_info) {
        .Struct => |info| {
            std.debug.print("\nParsed {s}:\n", .{@typeName(T)});
            inline for (info.fields) |field| {
                const value = @field(cfg, field.name);
                switch (@TypeOf(value)) {
                    []const u8 => std.debug.print("  {s}: {s}\n", .{ field.name, value }),
                    ?[]const u8 => if (value) |v| {
                        std.debug.print("  {s}: {s}\n", .{ field.name, v });
                    },
                    []const config.schema.Source => std.debug.print("  {s}: {d} sources\n", .{ field.name, value.len }),
                    else => {}, // Skip other types
                }
            }
        },
        else => {},
    }
}
