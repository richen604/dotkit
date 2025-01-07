const std = @import("std");
const output = @import("output.zig");
const version = @import("../version.zig").version;
const validation = @import("validation.zig");
const prompt = @import("prompt.zig");
const params = @import("params.zig");
const err = @import("utils").err;

pub const Command = enum {
    init,
    list,
    install,
    remove,
    status,
    debug,

    pub fn fromString(str: []const u8) !Command {
        return std.meta.stringToEnum(Command, str) orelse return error.InvalidCommand;
    }
};

pub fn run(allocator: std.mem.Allocator) !void {
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Initialize error handler with correct scope
    var error_handler = err.ErrorHandler.init(.cli);

    const issue_url = "https://github.com/richen604/dotkit/issues";
    const banner_text = try std.fmt.allocPrint(std.heap.page_allocator, "🥡 Dotkit - v{s} Alpha - Issues: {s}", .{ version, issue_url });
    defer std.heap.page_allocator.free(banner_text);
    const colored_title = try output.color(banner_text, output.Color.theme.orange);
    defer std.heap.page_allocator.free(colored_title);
    try output.showBanner(colored_title);

    if (args.len < 2) {
        try showDebugOutput();

        try showUsage();
        return err.DotkitError.MissingArgument;
    }

    // Parse command
    const cmd = Command.fromString(args[1]) catch |e| {
        error_handler.handle(.{
            .error_type = err.DotkitError.InvalidCommand,
            .message = try std.fmt.allocPrint(allocator, "Unknown command: {s}", .{args[1]}),
            .source = e,
        });
        try showUsage();
        return err.DotkitError.InvalidCommand;
    };

    // Execute command with error handling
    switch (cmd) {
        .init => {
            validation.rules.init.validate(args[2..]) catch |e| {
                error_handler.handle(.{
                    .error_type = err.DotkitError.InvalidArgument,
                    .message = "Invalid arguments for init command",
                    .source = e,
                });
                return err.DotkitError.InvalidArgument;
            };
            cmdInit() catch |e| {
                error_handler.handle(.{
                    .error_type = err.DotkitError.ConfigValidationFailed,
                    .message = "Failed to initialize configuration",
                    .source = e,
                });
                return err.DotkitError.ConfigValidationFailed;
            };
        },
        .list => {
            try validation.rules.list.validate(args[2..]);
            try cmdList();
        },
        .install => {
            try validation.rules.install.validate(args[2..]);
            try cmdInstall(args[2..]);
        },
        .remove => {
            try validation.rules.remove.validate(args[2..]);
            try cmdRemove(args[2..]);
        },
        .status => {
            try validation.rules.status.validate(args[2..]);
            try cmdStatus();
        },
        .debug => {
            try validation.rules.debug.validate(args[2..]);
            try showDebugOutput();
        },
    }
}

fn showDebugOutput() !void {
    // Theme colors
    const orange_text = try output.color("Theme Orange", output.Color.theme.orange);
    defer std.heap.page_allocator.free(orange_text);
    const cyan_text = try output.color("Theme Cyan", output.Color.theme.cyan);
    defer std.heap.page_allocator.free(cyan_text);

    // Standard colors
    const red_text = try output.color("Red", output.Color.red);
    defer std.heap.page_allocator.free(red_text);
    const green_text = try output.color("Green", output.Color.green);
    defer std.heap.page_allocator.free(green_text);
    const blue_text = try output.color("Blue", output.Color.blue);
    defer std.heap.page_allocator.free(blue_text);

    // Custom RGB color
    const custom_rgb = try output.color("Custom RGB (128,0,255)", output.Color.rgb(128, 0, 255));
    defer std.heap.page_allocator.free(custom_rgb);

    try output.printBoxed(
        \\Theme Colors: {s} | {s}
        \\Basic Colors: {s} | {s} | {s}
        \\Custom Color: {s}
    , .{
        orange_text, cyan_text,
        red_text,    green_text,
        blue_text,   custom_rgb,
    });
}

fn showUsage() !void {
    const usage =
        \\🥡 Usage: dotkit <command> [options]
        \\
        \\Commands:
        \\  init                 Initialize a new dotkit configuration
        \\  list                 List available modules
        \\  install [module]     Install all modules or a specific module
        \\  remove [module]      Remove all modules or a specific module
        \\  status              Show status of all configured modules
        \\  debug               Show debug color output
        \\
    ;
    try output.print("{s}", .{usage});
}

fn cmdInit() !void {
    const allocator = std.heap.page_allocator;
    const name = try prompt.input("Enter project name", allocator);
    defer allocator.free(name);

    try params.validateName(name);

    const should_proceed = try prompt.confirm("Initialize project?");
    if (!should_proceed) {
        try output.print("Cancelled\n", .{});
        return;
    }

    const start_time = std.time.nanoTimestamp();

    var spinner = try output.createSpinner("Initializing new configuration");
    defer spinner.deinit();

    // Artificial delay to show progress spinner
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        try spinner.tick();
        std.time.sleep(50 * std.time.ns_per_ms);
    }

    try spinner.success(try std.fmt.allocPrint(std.heap.page_allocator, "Created new dotkit configuration for {s}!", .{name}));
    try output.printElapsedTime(start_time);
}

fn cmdList() !void {
    try output.print("Available modules would be listed here\n", .{});
}

fn cmdInstall(args: []const []const u8) !void {
    const module = if (args.len > 0) args[0] else "all modules";
    try output.print("Would install: {s}\n", .{module});
}

fn cmdRemove(args: []const []const u8) !void {
    const module = if (args.len > 0) args[0] else "all modules";
    try output.print("Would remove: {s}\n", .{module});
}

fn cmdStatus() !void {
    try output.print("Would show status of all modules\n", .{});
}
