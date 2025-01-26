const std = @import("std");
const schema = @import("schema.zig");
const toml = @import("toml");
const err = @import("utils").err;

/// Get the error set from the TOML parser's parseFile function
fn TomlParseError(comptime T: type) type {
    return @typeInfo(@typeInfo(@TypeOf(toml.Parser(T).parseFile)).Fn.return_type.?).ErrorUnion.error_set;
}

/// Combined error set for parsing operations
pub const ParseErr = TomlParseError(schema.Module) || err.DotkitError;

/// Union type to hold either config type
pub const Config = union(enum) {
    module: schema.Module,
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
    var module_parser = toml.Parser(schema.Module).init(allocator);
    defer module_parser.deinit();

    if (module_parser.parseFile(path)) |result| {
        var module_config = result.value;
        if (module_config.validate()) {
            // If validation succeeds, it's a valid module config
            const copied_config = try module_config.clone(allocator);
            result.deinit();
            return Config{ .module = copied_config };
        } else |validation_err| {
            if (validation_err == err.DotkitError.MissingFiles) {
                // Has module fields but no files - invalid module format
                result.deinit();
                return err.DotkitError.InvalidModuleFormat;
            }
        }
        result.deinit();
    } else |parse_err| {
        if (parse_err == error.FileNotFound) return error.FileNotFound;
        if (parse_err == error.InvalidCharacter) return err.DotkitError.ConfigParseError;
        return parse_err;
    }

    // Try as global config
    var global_parser = toml.Parser(schema.GlobalConfig).init(allocator);
    defer global_parser.deinit();

    if (global_parser.parseFile(path)) |result| {
        var global_config = result.value;
        if (global_config.validate()) {
            // If validation succeeds, it's a valid global config
            const copied_config = try global_config.clone(allocator);
            result.deinit();
            return Config{ .global = copied_config };
        } else |validation_err| {
            if (validation_err == err.DotkitError.MissingModules) {
                // Has global fields but no modules - invalid global format
                result.deinit();
                return err.DotkitError.InvalidGlobalFormat;
            }
        }
        result.deinit();
    } else |parse_err| {
        if (parse_err == error.FileNotFound) return error.FileNotFound;
        if (parse_err == error.InvalidCharacter) return err.DotkitError.ConfigParseError;
        return parse_err;
    }

    return err.DotkitError.InvalidConfig;
}
