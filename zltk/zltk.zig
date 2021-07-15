pub usingnamespace @import("core.zig");

pub const Button = @import("widgets/Button.zig");
pub const Fixed = @import("widgets/Fixed.zig");
pub const Entry = @import("widgets/Entry.zig");

const std = @import("std");
pub fn new(alloc: *std.mem.Allocator) anyerror!State {
    return State.new(alloc);
}
