const std = @import("std");
const output = @import("output.zig");

pub const ValidationError = error{
    MissingRequiredParam,
    TooManyParams,
};

pub const CommandParams = struct {
    min_args: usize,
    max_args: usize,
    command_name: []const u8,

    pub fn validate(self: CommandParams, args: []const []const u8) !void {
        if (args.len < self.min_args) {
            try output.showError("'{s}' requires at least {d} parameter(s)", .{ self.command_name, self.min_args });
            return ValidationError.MissingRequiredParam;
        }

        if (args.len > self.max_args) {
            try output.showError("'{s}' accepts at most {d} parameter(s)", .{ self.command_name, self.max_args });
            return ValidationError.TooManyParams;
        }
    }
};

pub const rules = struct {
    pub const install = CommandParams{
        .min_args = 0,
        .max_args = 1,
        .command_name = "install",
    };

    pub const remove = CommandParams{
        .min_args = 1,
        .max_args = 1,
        .command_name = "remove",
    };

    pub const init = CommandParams{
        .min_args = 0,
        .max_args = 0,
        .command_name = "init",
    };

    pub const list = CommandParams{
        .min_args = 0,
        .max_args = 0,
        .command_name = "list",
    };

    pub const status = CommandParams{
        .min_args = 0,
        .max_args = 0,
        .command_name = "status",
    };

    pub const debug = CommandParams{
        .min_args = 0,
        .max_args = 0,
        .command_name = "debug",
    };
};
