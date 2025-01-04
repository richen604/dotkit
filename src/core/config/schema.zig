const std = @import("std");

/// Represents a file mapping in a module configuration
pub const FileMapping = struct {
    source: []const u8,
    target: []const u8,
    executable: bool = false,

    pub fn init() FileMapping {
        return .{
            .source = "",
            .target = "",
            .executable = false,
        };
    }
};

/// Represents hooks that can be run at different stages
pub const Hooks = struct {
    start: ?[][]const u8 = null,
    pre_install: ?[][]const u8 = null,
    post_install: ?[][]const u8 = null,
    pre_remove: ?[][]const u8 = null,

    pub fn init() Hooks {
        return .{
            .start = null,
            .pre_install = null,
            .post_install = null,
            .pre_remove = null,
        };
    }
};

/// TODO: add module type
/// Source types for module configurations
pub const SourceType = enum {
    path,
    git,
};

/// Represents a module source configuration
pub const Source = struct {
    type: SourceType,
    location: ?[]const u8 = null, // for path type
    url: ?[]const u8 = null, // for git type
    branch: ?[]const u8 = null,
    ref: ?[]const u8 = null,
    enable: bool = false,
    config: ?ModuleConfig = null,

    pub fn init() Source {
        return .{
            .type = .path,
            .location = null,
            .url = null,
            .branch = null,
            .ref = null,
            .enable = false,
            .config = null,
        };
    }

    pub fn validate(self: Source) !void {
        switch (self.type) {
            .path => if (self.location == null) return error.MissingPathLocation,
            .git => if (self.url == null) return error.MissingGitUrl,
        }
    }
};

/// Represents a single module configuration
pub const ModuleConfig = struct {
    name: []const u8,
    namespace: []const u8,
    category: []const u8,
    description: ?[]const u8 = null,
    dependencies: ?[][]const u8 = null,
    config_path: ?[]const u8 = null,
    files: []FileMapping,
    hooks: ?Hooks = null,

    pub fn init() ModuleConfig {
        return .{
            .name = "",
            .namespace = "",
            .category = "",
            .description = null,
            .dependencies = null,
            .config_path = null,
            .files = &[_]FileMapping{},
            .hooks = null,
        };
    }

    pub fn validate(self: ModuleConfig) !void {
        if (self.name.len == 0) return error.MissingName;
        if (self.namespace.len == 0) return error.MissingNamespace;
        if (self.category.len == 0) return error.MissingCategory;
    }
};

/// Represents the global configuration
pub const GlobalConfig = struct {
    name: ?[]const u8 = null,
    namespace: []const u8,
    description: ?[]const u8 = null,
    backup_path: ?[]const u8 = null,
    hooks: ?Hooks = null,
    modules: std.StringHashMap([]Source),

    pub fn init(allocator: std.mem.Allocator) GlobalConfig {
        return .{
            .name = null,
            .namespace = "",
            .description = null,
            .backup_path = null,
            .hooks = null,
            .modules = std.StringHashMap([]Source).init(allocator),
        };
    }

    pub fn validate(self: GlobalConfig) !void {
        if (self.namespace.len == 0) return error.MissingNamespace;
    }

    pub fn deinit(self: *GlobalConfig) void {
        self.modules.deinit();
    }
};
