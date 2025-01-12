pub const config = struct {
    pub const schema = @import("core/config/schema.zig");
    pub const parser = @import("core/config/parser.zig");
};

pub const source = struct {
    pub const git = @import("core/source/git.zig");
};
