const std = @import("std");
const fs = std.fs;
const utils = @import("utils");
const logger = utils.logger;
const err = utils.err;

pub const GitError = error{
    CloneError,
    InvalidUrl,
    DirectoryExists,
    DirectoryCreationFailed,
};

// TODO: perf: async git cloning with event loop
// TODO: feat: cli progress bar for git cloning
/// syncronously clones a git repository to the specified destination
/// Parameters:
///   - allocator: Memory allocator
///   - url: Git repository URL
///   - dest_path: Destination directory path
pub fn cloneRepo(
    allocator: std.mem.Allocator,
    url: []const u8,
    dest_path: []const u8,
) !void {
    // Validate inputs
    if (url.len == 0) {
        return GitError.InvalidUrl;
    }

    // Check if destination exists
    if (try utils.fs.exists(dest_path)) {
        return GitError.DirectoryExists;
    }

    // Create destination directory
    utils.fs.ensureDir(dest_path) catch {
        return GitError.DirectoryCreationFailed;
    };

    // Prepare git clone command
    var child = std.process.Child.init(&[_][]const u8{ "git", "clone", url, dest_path }, allocator);

    // Configure pipes for output
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    // Start the process
    try child.spawn();

    // Create buffer for reading output
    var buffer: [1024]u8 = undefined;

    // Read stdout in a loop
    while (true) {
        const bytes_read = try child.stdout.?.read(&buffer);
        if (bytes_read == 0) break;
    }

    // Wait for completion
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                // Try to read stderr for error details
                if (child.stderr) |stderr| {
                    _ = try stderr.readAll(&buffer);
                }
                return GitError.CloneError;
            }
        },
        else => {
            return GitError.CloneError;
        },
    }
}
