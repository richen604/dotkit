const std = @import("std");
const cli = @import("cli").commands;

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize CLI
    try cli.run(allocator);
}
