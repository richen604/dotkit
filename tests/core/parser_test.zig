const std = @import("std");
const testing = std.testing;
const config = @import("core").config;
const helpers = @import("helpers");
const err = @import("utils").err;

test "config parser tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "Config Parser");
    defer suite.deinit();

    // Unified config loading test
    try suite.runTest("load module config", struct {
        fn run() !void {
            var config_result = try config.parser.loadConfig(testing.allocator, "tests/fixtures/module.toml");
            defer config_result.deinit(testing.allocator);

            switch (config_result) {
                .module => |module_config| {
                    try testing.expectEqualStrings("test-module", module_config.name);
                    try testing.expectEqualStrings("test", module_config.namespace);
                    try testing.expectEqualStrings("testing", module_config.category);

                    if (module_config.description) |desc| {
                        try testing.expectEqualStrings("A test module", desc);
                    }

                    try testing.expect(module_config.files.len == 1);
                    const file = module_config.files[0];
                    try testing.expectEqualStrings("src/test", file.source);
                    try testing.expectEqualStrings("~/.config/test", file.target);
                },
                .global => unreachable,
            }
        }
    }.run);

    // Global config loading test
    try suite.runTest("load global config", struct {
        fn run() !void {
            var config_result = try config.parser.loadConfig(testing.allocator, "tests/fixtures/global.toml");
            defer config_result.deinit(testing.allocator);

            switch (config_result) {
                .global => |global_config| {
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

                    try testing.expect(global_config.modules.len == 1);
                    const module = global_config.modules[0];
                    try testing.expectEqualStrings("core", module.name);

                    try testing.expect(module.sources.len == 1);
                    const source = module.sources[0];
                    if (source.url) |url| {
                        try testing.expectEqualStrings("https://github.com/example/core.git", url);
                    }
                    try testing.expect(source.enable);
                },
                .module => unreachable,
            }
        }
    }.run);

    // Invalid file test
    try suite.runTest("invalid file handling", struct {
        fn run() !void {
            try testing.expectError(error.FileNotFound, config.parser.loadConfig(testing.allocator, "nonexistent.toml"));
        }
    }.run);

    // Test empty config file
    try suite.runTest("empty config handling", struct {
        fn run() !void {
            try testing.expectError(err.DotkitError.InvalidConfig, config.parser.loadConfig(testing.allocator, "tests/fixtures/empty.toml"));
        }
    }.run);

    // Test module config without files
    try suite.runTest("module without files", struct {
        fn run() !void {
            try testing.expectError(err.DotkitError.InvalidModuleFormat, config.parser.loadConfig(testing.allocator, "tests/fixtures/module_no_files.toml"));
        }
    }.run);

    // Test global config without modules
    try suite.runTest("global without modules", struct {
        fn run() !void {
            try testing.expectError(err.DotkitError.InvalidGlobalFormat, config.parser.loadConfig(testing.allocator, "tests/fixtures/global_no_modules.toml"));
        }
    }.run);

    // Test malformed TOML
    try suite.runTest("malformed toml", struct {
        fn run() !void {
            try testing.expectError(err.DotkitError.ConfigParseError, config.parser.loadConfig(testing.allocator, "tests/fixtures/malformed.toml"));
        }
    }.run);

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
