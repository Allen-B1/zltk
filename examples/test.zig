const std = @import("std");
const zltk = @import("zltk");

pub fn main() !void {
    var z = try zltk.new(std.heap.c_allocator);

    var win = try zltk.Window.new(&z, zltk.Dimen{.w=500,.h=500});
    try win.set_title("hello world");
    try win.set_show(true);

    try z.run();
}