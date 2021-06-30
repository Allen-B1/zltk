const actual = @import("xcb/xcb.zig");

pub usingnamespace @import("defs.zig");

pub const Connection: type = actual.Connection;
pub const Window: type = actual.Window;
