const std = @import("std");
const schema = @import("schema.zig");
const toml = @import("toml");
const err = @import("utils").err;

/// Get the error set from the TOML parser's parseFile function
fn TomlParseError(comptime T: type) type {
    return @typeInfo(@typeInfo(@TypeOf(toml.Parser(T).parseFile)).Fn.return_type.?).ErrorUnion.error_set;
}

// TODO: perf: optimize memory usage by avoiding double allocation in config parsing
// Consider taking ownership of result.value instead of cloning

/// Combined error set for parsing operations
pub const ParseErr = TomlParseError(schema.ModuleConfig) || err.DotkitError;

pub fn loadModuleConfig(allocator: std.mem.Allocator, path: []const u8) ParseErr!schema.ModuleConfig {
    var parser = toml.Parser(schema.ModuleConfig).init(allocator);
    defer parser.deinit();

    var result = try parser.parseFile(path);

    var config = result.value;
    try config.validate();

    // Create a deep copy of the config to return
    const copied_config = try config.clone(allocator);
    result.deinit();

    return copied_config;
}

pub fn loadGlobalConfig(allocator: std.mem.Allocator, path: []const u8) ParseErr!schema.GlobalConfig {
    var parser = toml.Parser(schema.GlobalConfig).init(allocator);
    defer parser.deinit();

    var result = try parser.parseFile(path);

    var config = result.value;
    try config.validate();

    // Create a deep copy of the config to return
    const copied_config = try config.clone(allocator);
    result.deinit();

    return copied_config;
}
