const std = @import("std");
const testing = std.testing;

/// Test case result information
pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    duration_ns: u64,
    error_msg: ?[]const u8 = null,
};

/// Test suite to group related tests
pub const TestSuite = struct {
    name: []const u8,
    allocator: std.mem.Allocator,
    results: std.ArrayList(TestResult),
    start_time: i64,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) TestSuite {
        return .{
            .name = name,
            .allocator = allocator,
            .results = std.ArrayList(TestResult).init(allocator),
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *TestSuite) void {
        self.results.deinit();
    }

    /// Run a test function and record its result
    pub fn runTest(self: *TestSuite, name: []const u8, test_fn: anytype) !void {
        const start = try std.time.Instant.now();

        test_fn() catch |err| {
            const duration = (try std.time.Instant.now()).since(start);
            const error_msg = try std.fmt.allocPrint(self.allocator, "Test failed with error: {s}", .{@errorName(err)});
            try self.results.append(.{
                .name = name,
                .passed = false,
                .duration_ns = duration,
                .error_msg = error_msg,
            });
            return;
        };

        const duration = (try std.time.Instant.now()).since(start);
        try self.results.append(.{
            .name = name,
            .passed = true,
            .duration_ns = duration,
        });
    }

    /// Print test results in a formatted way
    pub fn printResults(self: TestSuite) void {
        const total_duration = @as(f64, @floatFromInt(std.time.milliTimestamp() - self.start_time)) / 1000.0;

        std.debug.print("\n=== Test Suite: {s} ===\n", .{self.name});

        var passed: usize = 0;
        for (self.results.items) |result| {
            const duration_ms = @as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0;
            const status = if (result.passed) "✓" else "✗";

            std.debug.print("{s} {s} ({d:.3}ms)\n", .{ status, result.name, duration_ms });

            if (!result.passed) {
                if (result.error_msg) |msg| {
                    std.debug.print("  Error: {s}\n", .{msg});
                }
            } else {
                passed += 1;
            }
        }

        const total = self.results.items.len;
        std.debug.print("\nResults: {d}/{d} passed ({d:.2}s)\n", .{ passed, total, total_duration });
    }
};

/// Helper to create temporary test directories
pub fn createTempTestDir(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const tmp_dir = try std.fmt.bufPrint(&buf, "zig-cache/tmp/{s}_{d}", .{ prefix, std.time.timestamp() });
    try std.fs.cwd().makePath(tmp_dir);
    return try allocator.dupe(u8, tmp_dir);
}

/// Helper to create a test file with contents
pub fn createTestFile(dir: []const u8, name: []const u8, contents: []const u8) !void {
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir, name });
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(contents);
}
