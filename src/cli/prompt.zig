const std = @import("std");
const output = @import("output.zig");

pub const PromptError = error{
    InvalidInput,
    IoError,
};

pub fn confirm(message: []const u8) !bool {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("{s} [y/N]: ", .{message});

    var buf: [4]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        const trimmed = std.mem.trim(u8, user_input, " \t\r\n");
        return std.ascii.eqlIgnoreCase(trimmed, "y") or
            std.ascii.eqlIgnoreCase(trimmed, "yes");
    }

    return false;
}

pub fn input(message: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("{s}: ", .{message});

    const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024);
    return std.mem.trim(u8, line, " \t\r\n");
}

pub fn select(message: []const u8, options: []const []const u8) !usize {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("{s}:\n", .{message});
    for (options, 0..) |option, i| {
        try stdout.print("{d}. {s}\n", .{ i + 1, option });
    }
    try stdout.print("Enter number (1-{d}): ", .{options.len});

    var buf: [16]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        const trimmed = std.mem.trim(u8, user_input, " \t\r\n");
        const selection = try std.fmt.parseInt(usize, trimmed, 10);

        if (selection < 1 or selection > options.len) {
            return PromptError.InvalidInput;
        }

        return selection - 1;
    }

    return PromptError.InvalidInput;
}
