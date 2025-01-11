const std = @import("std");

pub const Color = struct {
    code: []const u8,

    // Theme colors using RGB values for precise control
    pub const theme = struct {
        pub const orange = Color{ .code = "\x1b[38;2;255;153;0m" }; // #FF9900
        pub const cyan = Color{ .code = "\x1b[38;2;0;204;204m" }; // #00CCCC
    };

    // ANSI standard colors for basic terminal support
    pub const red = Color{ .code = "\x1b[31m" };
    pub const green = Color{ .code = "\x1b[32m" };
    pub const yellow = Color{ .code = "\x1b[33m" };
    pub const blue = Color{ .code = "\x1b[34m" };
    pub const magenta = Color{ .code = "\x1b[35m" };
    pub const cyan = Color{ .code = "\x1b[36m" };
    pub const white = Color{ .code = "\x1b[37m" };

    // Create a color from RGB values
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{
            .code = std.fmt.allocPrint(
                std.heap.page_allocator,
                "\x1b[38;2;{d};{d};{d}m",
                .{ r, g, b },
            ) catch "\x1b[37m", // Fallback to white on allocation failure
        };
    }
};

// UI Constants
pub const ui = struct {
    // Box drawing characters
    pub const box = struct {
        pub const top_left = "╭";
        pub const top_right = "╮";
        pub const bottom_left = "╰";
        pub const bottom_right = "╯";
        pub const horizontal = "─";
        pub const vertical = "│";
    };

    // Spinner animation frames
    pub const spinner = struct {
        pub const frames = [_][]const u8{ "⠋", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽", "⣾" };
        pub const interval_ms = 80;
    };

    // Status indicators
    pub const indicators = struct {
        pub const success = "✓";
        pub const err = "❌";
        pub const warning = "⚠";
    };

    // Banner
    pub const banner = struct {
        pub const line = "━━━━━━━━━━━━━━━━━━━━━━";
    };

    // Terminal defaults
    pub const terminal = struct {
        pub const default_width = 80;
        pub const max_input_length = 1024;
    };
};
