const std = @import("std");
const core = @import("core");
const schema = core.config.schema;
const err = @import("utils").err;
const fs = @import("utils").fs;

pub const LinkOptions = struct {
    backup: bool = true,
    force: bool = false,
    dry_run: bool = false,
};

pub const SymlinkManager = struct {
    allocator: std.mem.Allocator,
    backup_dir: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, backup_dir: ?[]const u8) SymlinkManager {
        return .{
            .allocator = allocator,
            .backup_dir = backup_dir,
        };
    }

    pub fn deinit(self: *SymlinkManager) void {
        if (self.backup_dir) |dir| {
            self.allocator.free(dir);
        }
    }

    pub fn createLink(self: *SymlinkManager, mapping: schema.FileMapping, options: LinkOptions) !void {
        const expanded_source = expandPath(self.allocator, mapping.source) catch {
            return err.DotkitError.SymlinkError;
        };
        defer self.allocator.free(expanded_source);

        // Source must exist
        if (!try fs.exists(expanded_source)) {
            return err.DotkitError.SourceNotFound;
        }

        const expanded_target = try expandPath(self.allocator, mapping.target);
        defer self.allocator.free(expanded_target);

        // Verify source exists and get its type
        const source_stat = std.fs.cwd().statFile(expanded_source) catch |e| {
            return switch (e) {
                error.FileNotFound => err.DotkitError.SourceNotFound,
                else => e,
            };
        };

        // Handle different source types
        switch (source_stat.kind) {
            .file => {}, // Regular file, proceed normally
            .directory => {}, // Directory, proceed normally
            .sym_link => {
                // For symlinks, verify the target exists
                var real_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                const real_path = try std.fs.cwd().readLink(expanded_source, &real_path_buf);
                _ = try std.fs.cwd().statFile(real_path);
            },
            else => return error.InvalidPath,
        }

        // Check for circular links
        try self.checkCircularLink(expanded_source, expanded_target);

        // Handle existing target
        const target_exists = blk: {
            const result = std.fs.cwd().access(expanded_target, .{}) catch |e| switch (e) {
                error.FileNotFound => break :blk false,
                else => return e,
            };
            _ = result; // Use the result to avoid the error
            break :blk true;
        };

        if (target_exists) {
            if (options.dry_run) return;

            if (!options.force) {
                return error.TargetExists;
            }

            if (options.backup) {
                try self.backupPath(expanded_target);
            }

            // Remove existing target
            std.fs.cwd().deleteFile(expanded_target) catch |e| switch (e) {
                error.FileNotFound => {}, // Ignore if file is already gone
                else => return e,
            };
        }

        if (options.dry_run) return;

        // Create parent directories if needed
        if (std.fs.path.dirname(expanded_target)) |parent_path| {
            try std.fs.cwd().makePath(parent_path);
        }

        // Create the symlink with relative path
        const rel_source = blk: {
            const target_dir = std.fs.path.dirname(expanded_target) orelse break :blk expanded_source;
            break :blk try std.fs.path.relative(self.allocator, target_dir, expanded_source);
        };
        defer if (std.fs.path.dirname(expanded_target) != null) self.allocator.free(rel_source);

        try std.fs.cwd().symLink(rel_source, expanded_target, .{});

        // Verify the symlink was created successfully by reading it
        var link_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        _ = try std.fs.cwd().readLink(expanded_target, &link_path_buf);

        if (mapping.executable) {
            const target_file = try std.fs.cwd().openFile(expanded_target, .{ .mode = .read_write });
            defer target_file.close();
            try target_file.chmod(0o755);
        }
    }

    pub fn removeLink(self: *SymlinkManager, target: []const u8, options: LinkOptions) !void {
        const expanded_target = try expandPath(self.allocator, target);
        defer self.allocator.free(expanded_target);

        // Verify it's a symlink before removing
        var link_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        _ = std.fs.cwd().readLink(expanded_target, &link_buf) catch |e| {
            return switch (e) {
                error.NotLink => err.DotkitError.NotASymlink,
                else => e,
            };
        };

        if (options.dry_run) return;

        if (options.backup) {
            try self.backupPath(expanded_target);
        }

        try std.fs.cwd().deleteFile(expanded_target);
    }

    fn backupPath(self: *SymlinkManager, path: []const u8) !void {
        const backup_dir = self.backup_dir orelse return error.BackupFailed;

        const timestamp = std.time.timestamp();
        const backup_name = try std.fmt.allocPrint(self.allocator, "{s}/{s}.{d}.bak", .{ backup_dir, std.fs.path.basename(path), timestamp });
        defer self.allocator.free(backup_name);

        // Create backup directory if it doesn't exist
        try std.fs.cwd().makePath(backup_dir);

        // Copy the file/directory to backup location
        try std.fs.cwd().copyFile(path, std.fs.cwd(), backup_name, .{});
    }

    fn checkCircularLink(_: *SymlinkManager, source: []const u8, target: []const u8) !void {
        // If target would be created inside the source path, it's circular
        if (std.mem.startsWith(u8, target, source)) {
            return err.DotkitError.CircularLink;
        }

        // If source is a file, check if target would create a directory with the same name
        const source_stat = std.fs.cwd().statFile(source) catch |e| {
            return switch (e) {
                error.FileNotFound => err.DotkitError.SourceNotFound,
                else => e,
            };
        };

        if (source_stat.kind == .file) {
            // If target path contains the source file as a directory component, it's circular
            const target_components = std.mem.split(u8, target, std.fs.path.sep_str);
            const source_basename = std.fs.path.basename(source);

            var iter = target_components;
            while (iter.next()) |component| {
                if (std.mem.eql(u8, component, source_basename)) {
                    return err.DotkitError.CircularLink;
                }
            }
        }
    }

    fn expandPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        if (path.len == 0) return err.DotkitError.InvalidPath;

        if (path[0] == '~') {
            const home = std.posix.getenv("HOME") orelse return err.DotkitError.HomeNotFound;
            return std.fmt.allocPrint(allocator, "{s}{s}", .{
                home,
                path[1..],
            });
        }

        return try std.fs.path.resolve(allocator, &.{path});
    }

    fn createParentDirs(path: []const u8) !void {
        const parent_path = std.fs.path.dirname(path) orelse return;
        try std.fs.cwd().makePath(parent_path);
    }
};
