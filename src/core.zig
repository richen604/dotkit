pub const config = struct {
    pub const schema = @import("core/config/schema.zig");
    pub const parser = @import("core/config/parser.zig");
    pub const validator = @import("core/config/validator.zig");
};
