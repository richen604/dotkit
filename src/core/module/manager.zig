const std = @import("std");
const schema = @import("../config/schema.zig");
const err = @import("utils").err;
const fs = @import("utils").fs;

/// Represents the state of a module
pub const ModuleState = enum {
    enabled,
    disabled,
    err,
};

/// Represents a loaded module instance
pub const LoadedModule = struct {
    config: schema.ModuleConfig,
    state: ModuleState,
    err: ?err.DotkitError,

    pub fn init(config: schema.ModuleConfig) LoadedModule {
        return .{
            .config = config,
            .state = .disabled,
            .err = null,
        };
    }

    pub fn deinit(self: *LoadedModule, allocator: std.mem.Allocator) void {
        self.config.deinit(allocator);
    }

    pub fn clone(self: LoadedModule, allocator: std.mem.Allocator) !LoadedModule {
        return LoadedModule{
            .config = try self.config.clone(allocator),
            .state = self.state,
            .err = self.err,
        };
    }
};

/// Manages module lifecycle and operations
pub const ModuleManager = struct {
    allocator: std.mem.Allocator,
    modules: std.StringHashMap(LoadedModule),

    pub fn init(allocator: std.mem.Allocator) ModuleManager {
        return .{
            .allocator = allocator,
            .modules = std.StringHashMap(LoadedModule).init(allocator),
        };
    }

    pub fn deinit(self: *ModuleManager) void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.modules.deinit();
    }

    fn getModuleKey(namespace: []const u8, name: []const u8, buffer: *[std.fs.MAX_PATH_BYTES]u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "{s}/{s}", .{ namespace, name });
    }

    /// Load a module from its configuration
    pub fn loadModule(self: *ModuleManager, config: schema.ModuleConfig) !void {
        // Validate module config
        try config.validate();

        // Create module key
        var key_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key = try getModuleKey(config.namespace, config.name, &key_buffer);

        // Check if module already exists
        if (self.modules.contains(key)) {
            return err.DotkitError.ModuleValidationFailed;
        }

        // Clone config for storage and create module
        var module = LoadedModule.init(try config.clone(self.allocator));
        errdefer module.deinit(self.allocator);

        // Store with duplicated key
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);

        try self.modules.put(owned_key, module);
    }

    /// Enable a module by namespace/name
    pub fn enableModule(self: *ModuleManager, namespace: []const u8, name: []const u8) !void {
        var key_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key = try getModuleKey(namespace, name, &key_buffer);

        if (self.modules.getPtr(key)) |module| {
            module.state = .enabled;
        } else {
            return err.DotkitError.ModuleNotFound;
        }
    }

    /// Disable a module by namespace/name
    pub fn disableModule(self: *ModuleManager, namespace: []const u8, name: []const u8) !void {
        var key_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key = try getModuleKey(namespace, name, &key_buffer);

        if (self.modules.getPtr(key)) |module| {
            module.state = .disabled;
        } else {
            return err.DotkitError.ModuleNotFound;
        }
    }

    /// Get a module by namespace/name
    pub fn getModule(self: *ModuleManager, namespace: []const u8, name: []const u8) !?*LoadedModule {
        var key_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const key = try getModuleKey(namespace, name, &key_buffer);

        return self.modules.getPtr(key);
    }

    /// List all loaded modules
    pub fn listModules(self: *ModuleManager) !std.ArrayList(LoadedModule) {
        var list = std.ArrayList(LoadedModule).init(self.allocator);
        errdefer list.deinit();

        var it = self.modules.iterator();
        while (it.next()) |entry| {
            try list.append(try entry.value_ptr.clone(self.allocator));
        }
        return list;
    }
};
