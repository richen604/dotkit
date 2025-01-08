const std = @import("std");
const testing = std.testing;
const schema = @import("core").config.schema;
const SymlinkManager = @import("fs").symlink.SymlinkManager;
const helpers = @import("helpers");

test "symlink manager tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "SymlinkManager");
    defer suite.deinit();

    // Basic operations test
    try suite.runTest("basic operations", struct {
        fn run() !void {
            const test_dir = try helpers.createTempTestDir(allocator, "symlink_basic");
            defer allocator.free(test_dir);
            defer std.fs.cwd().deleteTree(test_dir) catch {};

            // Create test file
            try helpers.createTestFile(test_dir, "test.txt", "test contents");

            var backup_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const backup_dir = try std.fmt.bufPrint(&backup_path_buf, "{s}/backup", .{test_dir});

            var manager = SymlinkManager.init(allocator, try allocator.dupe(u8, backup_dir));
            defer manager.deinit();

            // Test paths
            var source_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            var target_path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const source = try std.fmt.bufPrint(&source_path_buf, "{s}/test.txt", .{test_dir});
            const target = try std.fmt.bufPrint(&target_path_buf, "{s}/link.txt", .{test_dir});

            // Create and verify link
            try manager.createLink(.{
                .source = source,
                .target = target,
                .executable = false,
            }, .{});

            // Verify link contents
            const target_file = try std.fs.cwd().openFile(target, .{});
            defer target_file.close();
            var buffer: [100]u8 = undefined;
            const bytes_read = try target_file.readAll(&buffer);
            try testing.expectEqualStrings("test contents", buffer[0..bytes_read]);

            // Remove and verify link removal
            try manager.removeLink(target, .{});

            // Create a mutable buffer for readLink
            var link_buffer: [100]u8 = undefined;
            try testing.expectError(error.FileNotFound, std.fs.cwd().readLink(target, &link_buffer));
        }
    }.run);

    // Print test results
    suite.printResults();
}
