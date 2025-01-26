const std = @import("std");

/// Core application errors
pub const DotkitError = error{
    // Config errors
    ConfigNotFound,
    InvalidConfig,
    InvalidModuleFormat,
    InvalidGlobalFormat,
    ConfigValidationFailed,
    ConfigParseError,
    MissingName,
    MissingNamespace,
    MissingCategory,
    MissingPathLocation,
    MissingGitUrl,
    MissingModuleConfig,
    MissingFiles,
    MissingModules,

    // Module errors
    ModuleNotFound,
    ModuleValidationFailed,
    ModuleInstallFailed,
    ModuleRemoveFailed,

    // Filesystem errors
    SymlinkError,
    BackupError,
    PathNotFound,
    PermissionDenied,
    SourceNotFound,
    TargetExists,
    InvalidPath,
    HomeNotFound,
    NotASymlink,
    CircularLink,
    BackupFailed,
    IsDirectory,

    // Source errors
    GitError,
    SourceValidationFailed,

    // CLI errors
    InvalidCommand,
    InvalidArgument,
    MissingArgument,
    TooManyParams,

    // General errors
    UnexpectedError,
    NotImplemented,
};

/// Error context for better error messages
pub const ErrorContext = struct {
    error_type: DotkitError,
    message: ?[]const u8,
    source: ?anyerror,

    // Add thread local storage for the last error context
    threadlocal var last_error: ErrorContext = undefined;

    pub fn init(
        error_type: DotkitError,
        message: ?[]const u8,
        source: ?anyerror,
    ) DotkitError {
        // Store the context in thread local storage
        last_error = .{
            .error_type = error_type,
            .message = message,
            .source = source,
        };
        return error_type;
    }

    pub fn getLastError() ErrorContext {
        return last_error;
    }
};

/// Error handler that formats and logs errors appropriately
pub const ErrorHandler = struct {
    pub const Scope = enum {
        cli,
        config,
        module,
        system,
    };

    scope: Scope,

    pub fn init(scope: Scope) ErrorHandler {
        return .{
            .scope = scope,
        };
    }

    pub fn handle(self: ErrorHandler, ctx: ErrorContext) void {
        // Handle each scope separately to keep the logging scoped properly
        switch (self.scope) {
            .cli => handleWithScope(std.log.scoped(.cli), ctx),
            .config => handleWithScope(std.log.scoped(.config), ctx),
            .module => handleWithScope(std.log.scoped(.module), ctx),
            .system => handleWithScope(std.log.scoped(.system), ctx),
        }
    }

    fn handleWithScope(log: anytype, ctx: ErrorContext) void {
        switch (ctx.error_type) {
            DotkitError.ConfigNotFound, DotkitError.ModuleNotFound, DotkitError.PathNotFound => {
                log.warn("{?s}", .{ctx.message});
            },
            DotkitError.InvalidConfig, DotkitError.ConfigValidationFailed, DotkitError.ModuleValidationFailed => {
                log.err("{?s}", .{ctx.message});
                if (ctx.source) |src| {
                    log.err("Caused by: {}", .{src});
                }
            },
            DotkitError.PermissionDenied => {
                log.err("{?s}\nPlease check file permissions and try again.", .{ctx.message});
            },
            DotkitError.GitError => {
                log.err("Git operation failed: {?s}", .{ctx.message});
                if (ctx.source) |src| {
                    log.err("Git error: {}", .{src});
                }
            },
            else => {
                log.err("Unexpected error: {?s}", .{ctx.message});
                if (ctx.source) |src| {
                    log.err("Source: {}", .{src});
                }
            },
        }
    }
};

/// Helper function to wrap system errors into DotkitErr
pub fn mapSystemError(err: anyerror) DotkitError {
    return switch (err) {
        error.FileNotFound => DotkitError.PathNotFound,
        error.AccessDenied => DotkitError.PermissionDenied,
        error.InvalidArgument => DotkitError.InvalidArgument,
        else => DotkitError.UnexpectedError,
    };
}
