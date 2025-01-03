const std = @import("std");

pub const DotkitError = error{
    ConfigNotFound,
    InvalidConfig,
    SymlinkError,
    BackupError,
    ModuleNotFound,
};
