const std = @import("std");
const testing = std.testing;
const git = @import("core").source.git;
const helpers = @import("helpers");
const fs = @import("utils").fs;
const logger = @import("utils").logger;

test "git source tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "Git Source");
    defer suite.deinit();

    // Test invalid URL handling
    try suite.runTest("invalid URL handling", struct {
        fn run() !void {
            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();

            const test_path = try tmp.dir.realpathAlloc(testing.allocator, ".");
            defer testing.allocator.free(test_path);

            try logger.log(.info, "Testing invalid URL handling with path: {s}", .{test_path});
            try testing.expectError(git.GitError.InvalidUrl, git.cloneRepo(testing.allocator, "", test_path));
        }
    }.run);

    // Test successful clone
    try suite.runTest("clone repository", struct {
        fn run() !void {
            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();

            const test_path = try tmp.dir.realpathAlloc(testing.allocator, ".");
            defer testing.allocator.free(test_path);

            // Clean up the directory if it exists
            if (try fs.exists(test_path)) {
                try logger.log(.info, "Cleaning up existing test directory: {s}", .{test_path});
                std.fs.deleteTreeAbsolute(test_path) catch |e| {
                    try logger.log(.printError, "Failed to clean up directory: {any}", .{e});
                };
            }

            // Use GitHub's official test repository
            const test_repo = "https://github.com/octocat/Spoon-Knife.git";
            try logger.log(.info, "Starting clone test with repo: {s}", .{test_repo});

            try git.cloneRepo(testing.allocator, test_repo, test_path);

            // Verify the .git directory exists
            const git_dir_path = try std.fs.path.join(testing.allocator, &[_][]const u8{ test_path, ".git" });
            defer testing.allocator.free(git_dir_path);

            const exists = try fs.exists(git_dir_path);
            try logger.log(.info, "Checking .git directory: {s} exists={}", .{ git_dir_path, exists });
            try testing.expect(exists);
        }
    }.run);

    // Print test results
    suite.printResults();
}
