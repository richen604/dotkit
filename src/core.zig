pub const config = struct {
    pub const schema = @import("core/config/schema.zig");
    pub const parser = @import("core/config/parser.zig");
};

pub const module = struct {
    pub const manager = @import("core/module/manager.zig");
};
