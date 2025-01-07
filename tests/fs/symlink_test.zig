const std = @import("std");
const testing = std.testing;
const schema = @import("core").config.schema;
const SymlinkManager = @import("fs").symlink.SymlinkManager;

fn setupTestDir(allocator: std.mem.Allocator) ![]const u8 {
    // Create a temporary test directory
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const tmp_dir = try std.fmt.bufPrint(&buf, "zig-cache/tmp/symlink_test_{d}", .{std.time.timestamp()});
    try std.fs.cwd().makePath(tmp_dir);
    std.debug.print("Created test directory: {s}\n", .{tmp_dir});
    return try allocator.dupe(u8, tmp_dir);
}

fn createTestFile(dir: []const u8, name: []const u8, contents: []const u8) !void {
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir, name });
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(contents);
}

test "SymlinkManager basic operations" {
    std.debug.print("Starting basic operations test\n", .{});

    // Setup
    const allocator = testing.allocator;
    const test_dir = try setupTestDir(allocator);
    defer allocator.free(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create test file
    const test_file = "test.txt";
    const test_contents = "test contents";
    try createTestFile(test_dir, test_file, test_contents);
    std.debug.print("Created test file: {s}/{s}\n", .{ test_dir, test_file });

    // Create backup directory
    var backup_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const backup_dir = try std.fmt.bufPrint(&backup_path_buf, "{s}/backup", .{test_dir});

    // Initialize SymlinkManager
    var manager = SymlinkManager.init(allocator, try allocator.dupe(u8, backup_dir));
    defer manager.deinit();

    // Create paths for source and target
    var source_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var target_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_path_buf, "{s}/{s}", .{ test_dir, test_file });
    const target = try std.fmt.bufPrint(&target_path_buf, "{s}/link.txt", .{test_dir});

    // Test createLink
    const mapping = schema.FileMapping{
        .source = source,
        .target = target,
        .executable = false,
    };

    try manager.createLink(mapping, .{});
    std.debug.print("Created symlink from {s} to {s}\n", .{ source, target });

    // Verify the symlink exists by trying to read it
    var link_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const link_target = try std.fs.cwd().readLink(target, &link_path_buf);
    try testing.expect(std.mem.indexOf(u8, link_target, test_file) != null);

    // Read through the symlink and verify contents
    const target_file = try std.fs.cwd().openFile(target, .{});
    defer target_file.close();
    var buffer: [100]u8 = undefined;
    const bytes_read = try target_file.readAll(&buffer);
    try testing.expectEqualStrings(test_contents, buffer[0..bytes_read]);

    // Test removeLink
    try manager.removeLink(target, .{});
    std.debug.print("Removed symlink at {s}\n", .{target});

    // Verify the symlink was removed
    try testing.expectError(error.FileNotFound, std.fs.cwd().readLink(target, &link_path_buf));
}

test "SymlinkManager backup functionality" {
    std.debug.print("Starting backup functionality test\n", .{});

    // Setup
    const allocator = testing.allocator;
    const test_dir = try setupTestDir(allocator);
    defer allocator.free(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create test files
    try createTestFile(test_dir, "source.txt", "source contents");
    try createTestFile(test_dir, "target.txt", "target contents");

    // Create backup directory
    var backup_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const backup_dir = try std.fmt.bufPrint(&backup_path_buf, "{s}/backup", .{test_dir});

    // Initialize SymlinkManager
    var manager = SymlinkManager.init(allocator, try allocator.dupe(u8, backup_dir));
    defer manager.deinit();

    // Create paths
    var source_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var target_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_path_buf, "{s}/source.txt", .{test_dir});
    const target = try std.fmt.bufPrint(&target_path_buf, "{s}/target.txt", .{test_dir});

    // Test createLink with force and backup options
    const mapping = schema.FileMapping{
        .source = source,
        .target = target,
        .executable = false,
    };

    try manager.createLink(mapping, .{ .force = true });

    // Verify backup was created
    var backup_iter = try std.fs.cwd().openDir(backup_dir, .{ .iterate = true });
    defer backup_iter.close();

    var found_backup = false;
    var iter = backup_iter.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "target.txt.")) {
            found_backup = true;
            break;
        }
    }

    try testing.expect(found_backup);

    if (found_backup) {
        std.debug.print("Backup file was created successfully in {s}\n", .{backup_dir});
    }
}

test "SymlinkManager error cases" {
    std.debug.print("Starting error cases test\n", .{});

    const allocator = testing.allocator;
    const test_dir = try setupTestDir(allocator);
    defer allocator.free(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    var manager = SymlinkManager.init(allocator, null);
    defer manager.deinit();

    // Test non-existent source
    const mapping = schema.FileMapping{
        .source = "nonexistent",
        .target = "target",
        .executable = false,
    };

    std.debug.print("Testing non-existent source file error\n", .{});
    try testing.expectError(error.SourceNotFound, manager.createLink(mapping, .{}));

    // Test circular link detection
    try createTestFile(test_dir, "file.txt", "contents");
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buf, "{s}/file.txt", .{test_dir});
    const circular_target = try std.fmt.bufPrint(&path_buf, "{s}/file.txt/circular", .{test_dir});

    std.debug.print("Testing circular link error with file: {s}\n", .{file_path});
    const circular_mapping = schema.FileMapping{
        .source = file_path,
        .target = circular_target,
        .executable = false,
    };

    try testing.expectError(error.CircularLink, manager.createLink(circular_mapping, .{}));
}
