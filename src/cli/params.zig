const std = @import("std");
const output = @import("output.zig");

pub const ParamError = error{
    InvalidFormat,
    MissingValue,
    InvalidValue,
};

pub fn parseKeyValue(arg: []const u8) !struct { key: []const u8, value: []const u8 } {
    const separator = std.mem.indexOf(u8, arg, "=") orelse
        return ParamError.InvalidFormat;

    const key = std.mem.trim(u8, arg[0..separator], " ");
    const value = std.mem.trim(u8, arg[separator + 1 ..], " ");

    if (key.len == 0) return ParamError.MissingValue;
    if (value.len == 0) return ParamError.MissingValue;

    return .{ .key = key, .value = value };
}

pub fn validatePath(path: []const u8) !void {
    // Basic path validation
    if (path.len == 0) return ParamError.InvalidValue;
    if (std.mem.indexOf(u8, path, "\x00") != null) return ParamError.InvalidValue;
}

pub fn validateName(name: []const u8) !void {
    // Basic name validation (alphanumeric + underscore)
    if (name.len == 0) return ParamError.InvalidValue;

    for (name) |char| {
        if (!std.ascii.isAlphanumeric(char) and char != '_' and char != '-') {
            return ParamError.InvalidValue;
        }
    }
}

pub fn getOptionValue(args: []const []const u8, option: []const u8) ?[]const u8 {
    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, option)) {
            if (i + 1 < args.len) {
                return args[i + 1];
            }
            return null;
        }
    }
    return null;
}
