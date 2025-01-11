const std = @import("std");
const consts = @import("consts");
pub const Color = consts.Color;

pub fn showBanner(text: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n{s}\n{s}\n", .{ consts.ui.banner.line, text, consts.ui.banner.line });
}

pub fn printBoxed(comptime fmt: []const u8, args: anytype) !void {
    const stdout = std.io.getStdOut().writer();
    const text = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
    defer std.heap.page_allocator.free(text);

    // Split text into lines
    var lines = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer lines.deinit();

    var line_start: usize = 0;
    for (text, 0..) |char, i| {
        if (char == '\n' or i == text.len - 1) {
            const line_end = if (char == '\n') i else i + 1;
            try lines.append(text[line_start..line_end]);
            line_start = i + 1;
        }
    }

    // Calculate visible width accounting for ANSI escape sequences
    var max_width: usize = 0;
    for (lines.items) |line| {
        var visible_width: usize = 0;
        var i: usize = 0;
        while (i < line.len) {
            if (line[i] == '\x1b') {
                // Skip ANSI escape sequence until 'm' character
                while (i < line.len and line[i] != 'm') : (i += 1) {}
                i += 1;
                continue;
            }
            visible_width += 1;
            i += 1;
        }
        max_width = @max(max_width, visible_width);
    }

    const box_width = max_width + 4;
    // Draw top border
    try stdout.print("╭", .{});
    for (0..box_width - 2) |_| try stdout.print("─", .{});
    try stdout.print("╮\n", .{});

    // Draw content
    for (lines.items) |line| {
        try stdout.print("│ {s}", .{line});
        // Calculate padding needed
        var visible_width: usize = 0;
        var i: usize = 0;
        while (i < line.len) {
            if (line[i] == '\x1b') {
                while (i < line.len and line[i] != 'm') : (i += 1) {}
                i += 1;
                continue;
            }
            visible_width += 1;
            i += 1;
        }
        const padding = max_width - visible_width;
        for (0..padding) |_| try stdout.print(" ", .{});
        try stdout.print(" │\n", .{});
    }

    // Draw bottom border
    try stdout.print("╰", .{});
    for (0..box_width - 2) |_| try stdout.print("─", .{});
    try stdout.print("╯\n", .{});
}

pub const Spinner = struct {
    message: []const u8,
    frame: usize,
    timer: std.time.Timer,

    const frames = consts.ui.spinner.frames;

    pub fn tick(self: *Spinner) !void {
        const elapsed = self.timer.read();
        if (elapsed >= consts.ui.spinner.interval_ms * std.time.ns_per_ms) {
            self.frame = (self.frame + 1) % frames.len;
            const stdout = std.io.getStdOut().writer();
            const colored_frame = try color(frames[self.frame], Color.theme.orange);
            defer std.heap.page_allocator.free(colored_frame);
            try stdout.print("\r{s} {s}", .{ colored_frame, self.message });
            self.timer.reset();
        }
    }

    pub fn deinit(self: *Spinner) void {
        _ = self;
        // Clear the spinner line
        const stdout = std.io.getStdOut().writer();
        stdout.print("\r\x1b[K", .{}) catch {};
    }

    pub fn success(self: *Spinner, message: ?[]const u8) !void {
        const stdout = std.io.getStdOut().writer();
        const final_message = message orelse self.message;
        const colored_checkmark = try color(consts.ui.indicators.success, Color.green);
        defer std.heap.page_allocator.free(colored_checkmark);
        try stdout.print("\r\x1b[K{s} {s}\n", .{ colored_checkmark, final_message });
    }
};

pub fn createSpinner(message: []const u8) !Spinner {
    const stdout = std.io.getStdOut().writer();
    const colored_frame = try color(Spinner.frames[0], Color.theme.orange);
    defer std.heap.page_allocator.free(colored_frame);
    try stdout.print("{s} {s}", .{ colored_frame, message });

    return Spinner{
        .message = message,
        .frame = 0,
        .timer = try std.time.Timer.start(),
    };
}

pub fn color(text: []const u8, col: Color) ![]const u8 {
    return try std.fmt.allocPrint(
        std.heap.page_allocator,
        "{s}{s}\x1b[0m",
        .{ col.code, text },
    );
}

pub fn getTerminalWidth() usize {
    if (@import("builtin").os.tag == .windows) {
        // Windows implementation unchanged
        var info: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (std.os.windows.kernel32.GetConsoleScreenBufferInfo(
            std.os.windows.kernel32.GetStdHandle(std.os.windows.HANDLE_STDOUT),
            &info,
        ) != 0) {
            return @intCast(info.dwSize.X);
        }
    } else {
        // Fixed Unix-like systems implementation
        var winsize: std.os.linux.winsize = undefined; // Changed from std.os.system.winsize
        if (std.os.linux.ioctl(1, std.os.linux.T.IOCGWINSZ, @intFromPtr(&winsize)) == 0) { // Updated ioctl path
            return winsize.ws_col;
        }
    }
    return 80; // fallback width
}

pub fn printElapsedTime(start_time: i128) !void {
    const stdout = std.io.getStdOut().writer();
    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = @as(f64, @floatFromInt(end_time - start_time));
    const elapsed_secs = elapsed_ns / @as(f64, @floatFromInt(std.time.ns_per_s));

    const time_text = try std.fmt.allocPrint(std.heap.page_allocator, "took {d:.2}s", .{elapsed_secs});
    defer std.heap.page_allocator.free(time_text);

    const colored_text = try color(time_text, Color.theme.cyan);
    defer std.heap.page_allocator.free(colored_text);

    try stdout.print("\r{s}\n", .{
        colored_text,
    });
}

pub fn print(comptime fmt: []const u8, args: anytype) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(fmt, args);
}

pub fn showError(comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
    defer std.heap.page_allocator.free(text);

    const error_text = try color(text, Color.red);
    defer std.heap.page_allocator.free(error_text);

    try print("❌ {s}\n", .{error_text});
}
