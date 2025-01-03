const std = @import("std");

pub const LogLevel = enum {
    debug,
    info,
    warn,
    printError,
};

pub fn log(level: LogLevel, comptime format: []const u8, args: anytype) !void {
    const stderr = std.io.getStdErr().writer();

    const prefix = switch (level) {
        .debug => "DEBUG: ",
        .info => "INFO: ",
        .warn => "WARN: ",
        .printError => "ERROR: ",
    };

    try stderr.print(prefix ++ format ++ "\n", args);
}
