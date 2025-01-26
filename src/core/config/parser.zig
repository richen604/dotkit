const std = @import("std");
const schema = @import("schema.zig");
const toml = @import("toml");
const err = @import("utils").err;

/// Get the error set from the TOML parser's parseFile function
fn TomlParseError(comptime T: type) type {
    return @typeInfo(@typeInfo(@TypeOf(toml.Parser(T).parseFile)).Fn.return_type.?).ErrorUnion.error_set;
}

/// Combined error set for parsing operations
pub const ParseErr = TomlParseError(schema.ModuleConfig) || err.DotkitError;

/// Union type to hold either config type
pub const Config = union(enum) {
    module: schema.ModuleConfig,
    global: schema.GlobalConfig,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .module => |*m| m.deinit(allocator),
            .global => |*g| g.deinit(allocator),
        }
    }
};

/// Load and parse a configuration file, automatically detecting the type
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8) ParseErr!Config {
    // First try as module config
    var module_parser = toml.Parser(schema.ModuleConfig).init(allocator);
    defer module_parser.deinit();

    if (module_parser.parseFile(path)) |result| {
        var module_config = result.value;
        // If it has files array, treat as module config
        if (module_config.files.len > 0) {
            try module_config.validate();
            const copied_config = try module_config.clone(allocator);
            result.deinit();
            return Config{ .module = copied_config };
        }
        result.deinit();
    } else |_| {}

    // Try as global config
    var global_parser = toml.Parser(schema.GlobalConfig).init(allocator);
    defer global_parser.deinit();

    var result = try global_parser.parseFile(path);
    var global_config = result.value;
    // If it has modules array, treat as global config
    if (global_config.modules.len > 0) {
        try global_config.validate();
        const copied_config = try global_config.clone(allocator);
        result.deinit();
        return Config{ .global = copied_config };
    }

    // If we get here, the config is invalid
    result.deinit();
    return error.InvalidConfigFormat;
}
