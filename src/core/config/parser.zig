const std = @import("std");
const schema = @import("schema.zig");
const Ymlz = @import("ymlz").Ymlz;
const validator = @import("validator.zig");

pub const ParseError = error{
    FileNotFound,
    InvalidConfig,
    OutOfMemory,
    InvalidCharacter,
    Unseekable,
} || std.fs.File.OpenError || std.fs.File.ReadError;

pub fn loadModuleConfig(allocator: std.mem.Allocator, path: []const u8) ParseError!schema.ModuleConfig {
    // Read file contents
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);

    // Parse YAML into ModuleConfig
    var ymlz = try Ymlz(schema.ModuleConfig).init(allocator);
    const config = try ymlz.loadRaw(content);

    // Validate the config
    try config.validate();

    return config;
}

pub fn loadGlobalConfig(allocator: std.mem.Allocator, path: []const u8) ParseError!schema.GlobalConfig {
    // Read file contents
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);

    // Parse YAML into GlobalConfig
    var ymlz = try Ymlz(schema.GlobalConfig).init(allocator);
    var config = try ymlz.loadRaw(content);

    // Validate the config
    try config.validate();

    return config;
}
