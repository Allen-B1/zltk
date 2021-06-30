pub usingnamespace @import("widgets/button.zig");
pub usingnamespace @import("core.zig");

const std = @import("std");
pub fn new(alloc: *std.mem.Allocator) anyerror!State {
    return State.new(alloc);
}
