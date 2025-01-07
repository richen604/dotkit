const std = @import("std");
const err = @import("utils").err;

/// Represents a file mapping in a module configuration
pub const FileMapping = struct {
    source: []const u8 = "",
    target: []const u8 = "",
    executable: bool = false,

    pub fn clone(self: FileMapping, allocator: std.mem.Allocator) !FileMapping {
        return FileMapping{
            .source = try allocator.dupe(u8, self.source),
            .target = try allocator.dupe(u8, self.target),
            .executable = self.executable,
        };
    }

    pub fn deinit(self: *FileMapping, allocator: std.mem.Allocator) void {
        allocator.free(self.source);
        allocator.free(self.target);
    }
};

/// Represents hooks that can be run at different stages
pub const Hooks = struct {
    start: ?[][]const u8 = null,
    pre_install: ?[][]const u8 = null,
    post_install: ?[][]const u8 = null,
    pre_remove: ?[][]const u8 = null,

    pub fn clone(self: Hooks, allocator: std.mem.Allocator) !Hooks {
        return Hooks{
            .start = if (self.start) |cmds| try cloneStringArray(allocator, cmds) else null,
            .pre_install = if (self.pre_install) |cmds| try cloneStringArray(allocator, cmds) else null,
            .post_install = if (self.post_install) |cmds| try cloneStringArray(allocator, cmds) else null,
            .pre_remove = if (self.pre_remove) |cmds| try cloneStringArray(allocator, cmds) else null,
        };
    }

    pub fn deinit(self: *Hooks, allocator: std.mem.Allocator) void {
        if (self.start) |cmds| freeStringArray(allocator, cmds);
        if (self.pre_install) |cmds| freeStringArray(allocator, cmds);
        if (self.post_install) |cmds| freeStringArray(allocator, cmds);
        if (self.pre_remove) |cmds| freeStringArray(allocator, cmds);
    }
};

/// Source types for module configurations
pub const SourceType = enum {
    path,
    git,
    module,
};

/// Represents a module source configuration
pub const Source = struct {
    type: ?SourceType = null,
    location: ?[]const u8 = null,
    url: ?[]const u8 = null,
    module: ?ModuleConfig = null,
    branch: ?[]const u8 = null,
    ref: ?[]const u8 = null,
    enable: bool = false,
    config: ?ModuleConfig = null,

    pub fn inferType(self: Source) SourceType {
        if (self.module != null) return .module;
        if (self.url != null) return .git;
        if (self.location != null) return .path;
        return .path; // default to path type
    }

    pub fn validate(self: *Source) err.DotkitError!void {
        // Infer and set type if not explicitly set
        if (self.type == null) {
            self.type = self.inferType();
        }

        switch (self.type.?) {
            .path => if (self.location == null) return err.DotkitError.MissingPathLocation,
            .git => if (self.url == null) return err.DotkitError.MissingGitUrl,
            .module => if (self.module == null) return err.DotkitError.MissingModuleConfig,
        }
    }

    pub fn clone(self: Source, allocator: std.mem.Allocator) !Source {
        return Source{
            .type = self.type,
            .location = if (self.location) |loc| try allocator.dupe(u8, loc) else null,
            .url = if (self.url) |u| try allocator.dupe(u8, u) else null,
            .module = if (self.module) |m| try m.clone(allocator) else null,
            .branch = if (self.branch) |b| try allocator.dupe(u8, b) else null,
            .ref = if (self.ref) |r| try allocator.dupe(u8, r) else null,
            .enable = self.enable,
            .config = if (self.config) |c| try c.clone(allocator) else null,
        };
    }

    pub fn deinit(self: *Source, allocator: std.mem.Allocator) void {
        if (self.location) |loc| allocator.free(loc);
        if (self.url) |u| allocator.free(u);
        if (self.module) |*m| m.deinit(allocator);
        if (self.branch) |b| allocator.free(b);
        if (self.ref) |r| allocator.free(r);
        if (self.config) |*c| c.deinit(allocator);
    }
};

/// Represents a single module configuration
pub const ModuleConfig = struct {
    name: []const u8 = "",
    namespace: []const u8 = "",
    category: []const u8 = "",
    description: ?[]const u8 = null,
    dependencies: ?[][]const u8 = null,
    config_path: ?[]const u8 = null,
    files: []FileMapping = &[_]FileMapping{},
    hooks: ?Hooks = null,

    pub fn clone(self: ModuleConfig, allocator: std.mem.Allocator) !ModuleConfig {
        var new_files = try allocator.alloc(FileMapping, self.files.len);
        for (self.files, 0..) |file, i| {
            new_files[i] = try file.clone(allocator);
        }

        return ModuleConfig{
            .name = try allocator.dupe(u8, self.name),
            .namespace = try allocator.dupe(u8, self.namespace),
            .category = try allocator.dupe(u8, self.category),
            .description = if (self.description) |desc| try allocator.dupe(u8, desc) else null,
            .dependencies = if (self.dependencies) |deps| blk: {
                var new_deps = try allocator.alloc([]const u8, deps.len);
                for (deps, 0..) |dep, i| {
                    new_deps[i] = try allocator.dupe(u8, dep);
                }
                break :blk new_deps;
            } else null,
            .config_path = if (self.config_path) |path| try allocator.dupe(u8, path) else null,
            .files = new_files,
            .hooks = if (self.hooks) |h| try h.clone(allocator) else null,
        };
    }

    pub fn deinit(self: *ModuleConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.namespace);
        allocator.free(self.category);
        if (self.description) |desc| allocator.free(desc);
        if (self.dependencies) |deps| {
            for (deps) |dep| allocator.free(dep);
            allocator.free(deps);
        }
        if (self.config_path) |path| allocator.free(path);
        for (self.files) |*file| {
            file.deinit(allocator);
        }
        allocator.free(self.files);
        if (self.hooks) |*h| h.deinit(allocator);
    }

    pub fn validate(self: ModuleConfig) err.DotkitError!void {
        if (self.name.len == 0) return err.DotkitError.MissingName;
        if (self.namespace.len == 0) return err.DotkitError.MissingNamespace;
        if (self.category.len == 0) return err.DotkitError.MissingCategory;
    }
};

/// Represents the global configuration
pub const GlobalConfig = struct {
    name: ?[]const u8 = null,
    namespace: []const u8 = "",
    description: ?[]const u8 = null,
    backup_path: ?[]const u8 = null,
    hooks: ?Hooks = null,
    modules: []ModuleEntry = &[_]ModuleEntry{},

    pub const ModuleEntry = struct {
        name: []const u8,
        sources: []Source,

        pub fn clone(self: ModuleEntry, allocator: std.mem.Allocator) !ModuleEntry {
            var new_sources = try allocator.alloc(Source, self.sources.len);
            for (self.sources, 0..) |src, i| {
                new_sources[i] = try src.clone(allocator);
            }

            return ModuleEntry{
                .name = try allocator.dupe(u8, self.name),
                .sources = new_sources,
            };
        }

        pub fn deinit(self: *ModuleEntry, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            for (self.sources) |*src| {
                src.deinit(allocator);
            }
            allocator.free(self.sources);
        }
    };

    pub fn clone(self: GlobalConfig, allocator: std.mem.Allocator) !GlobalConfig {
        var new_modules = try allocator.alloc(ModuleEntry, self.modules.len);
        for (self.modules, 0..) |module, i| {
            new_modules[i] = try module.clone(allocator);
        }

        return GlobalConfig{
            .name = if (self.name) |n| try allocator.dupe(u8, n) else null,
            .namespace = try allocator.dupe(u8, self.namespace),
            .description = if (self.description) |desc| try allocator.dupe(u8, desc) else null,
            .backup_path = if (self.backup_path) |path| try allocator.dupe(u8, path) else null,
            .hooks = if (self.hooks) |h| try h.clone(allocator) else null,
            .modules = new_modules,
        };
    }

    pub fn deinit(self: *GlobalConfig, allocator: std.mem.Allocator) void {
        if (self.name) |n| allocator.free(n);
        allocator.free(self.namespace);
        if (self.description) |desc| allocator.free(desc);
        if (self.backup_path) |path| allocator.free(path);
        if (self.hooks) |*h| h.deinit(allocator);
        for (self.modules) |*module| {
            module.deinit(allocator);
        }
        allocator.free(self.modules);
    }

    pub fn validate(self: GlobalConfig) err.DotkitError!void {
        if (self.namespace.len == 0) return err.DotkitError.MissingNamespace;

        // Validate all sources in all modules
        for (self.modules) |module| {
            for (module.sources) |source| {
                var mutable_source = source;
                try mutable_source.validate();
            }
        }
    }
};

fn cloneStringArray(allocator: std.mem.Allocator, strings: []const []const u8) ![][]const u8 {
    var result = try allocator.alloc([]const u8, strings.len);
    for (strings, 0..) |str, i| {
        result[i] = try allocator.dupe(u8, str);
    }
    return result;
}

fn freeStringArray(allocator: std.mem.Allocator, strings: [][]const u8) void {
    for (strings) |str| allocator.free(str);
    allocator.free(strings);
}
