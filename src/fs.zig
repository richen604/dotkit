const core = @import("core");

pub const symlink = struct {
    const symlink_impl = @import("fs/symlink.zig");
    pub const SymlinkManager = symlink_impl.SymlinkManager;
    pub const LinkOptions = symlink_impl.LinkOptions;
    pub const SymlinkError = symlink_impl.SymlinkError;
};
