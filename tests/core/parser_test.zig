const std = @import("std");
const testing = std.testing;
const config = @import("core").config;

test "@core.config.parser.load_module_config" {
    // Load and verify the config from the fixture file
    var module_config = try config.parser.loadModuleConfig(testing.allocator, "tests/fixtures/module.toml");
    defer module_config.deinit(testing.allocator);

    try testing.expectEqualStrings("test-module", module_config.name);
    try testing.expectEqualStrings("test", module_config.namespace);

    std.debug.print("\nModule Config:\n", .{});
    std.debug.print("  name: {s}\n  namespace: {s}\n  category: {s}\n", .{
        module_config.name,
        module_config.namespace,
        module_config.category,
    });
    if (module_config.description) |desc| {
        std.debug.print("  description: {s}\n", .{desc});
    }

    std.debug.print("\n  Files ({d}):\n", .{module_config.files.len});
    for (module_config.files) |file| {
        std.debug.print("    - source: {s}\n      target: {s}\n      executable: {}\n", .{
            file.source,
            file.target,
            file.executable,
        });
    }
}

test "@core.config.parser.invalid_file" {
    try testing.expectError(error.FileNotFound, config.parser.loadModuleConfig(testing.allocator, "nonexistent.toml"));
}

test "@core.config.parser.load_global_config" {
    // Load and verify the config from the fixture file
    var global_config = try config.parser.loadGlobalConfig(testing.allocator, "tests/fixtures/global.toml");
    defer global_config.deinit(testing.allocator);

    try testing.expectEqualStrings("test-global", global_config.namespace);
    if (global_config.name) |name| {
        try testing.expectEqualStrings("test-config", name);
    }

    std.debug.print("\nGlobal Config:\n", .{});
    if (global_config.name) |name| {
        std.debug.print("  name: {s}\n", .{name});
    }
    std.debug.print("  namespace: {s}\n", .{global_config.namespace});
    if (global_config.description) |desc| {
        std.debug.print("  description: {s}\n", .{desc});
    }
    if (global_config.backup_path) |path| {
        std.debug.print("  backup_path: {s}\n", .{path});
    }

    std.debug.print("\n  Modules ({d}):\n", .{global_config.modules.len});
    for (global_config.modules) |module| {
        std.debug.print("    {s}:\n", .{module.name});
        for (module.sources) |source| {
            std.debug.print("      - type: {?}\n", .{source.type});
            if (source.location) |loc| {
                std.debug.print("        location: {s}\n", .{loc});
            }
            if (source.url) |url| {
                std.debug.print("        url: {s}\n", .{url});
            }
            if (source.branch) |branch| {
                std.debug.print("        branch: {s}\n", .{branch});
            }
            if (source.ref) |ref| {
                std.debug.print("        ref: {s}\n", .{ref});
            }
            std.debug.print("        enabled: {}\n", .{source.enable});
        }
    }
}

test "@core.config.parser.invalid_global_file" {
    try testing.expectError(error.FileNotFound, config.parser.loadGlobalConfig(testing.allocator, "nonexistent.toml"));
}
