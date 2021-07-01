const interface = @import("interface");
const std = @import("std");
const zltk = @import("zltk");

pub fn main() !void {
    var z = try zltk.new(std.heap.c_allocator);

    var win = try zltk.Window.new(&z, zltk.Dimen{.w=500,.h=500});
    try win.set_title("hello world");
    try win.set_show(true);

    var root: zltk.Fixed = undefined;
    root.init(std.heap.c_allocator);
    root.background = .{.r=255,.g=255,.b=255};
    try win.add(interface.new(zltk.Widget, zltk.Fixed.Impl, &root));

    const button_style = zltk.Button.Style{
        .background = .{.r=0,.g=0,.b=255},
        .active_background = .{.r=0,.g=0,.b=255},
        .foreground = .{.r=255,.g=255,.b=255},
        .font = "6x13"
    };

    var button = zltk.Button{
        .text = "Button",
        .style = &button_style
    };
    try root.add(interface.new(zltk.Widget, zltk.Button.Impl, &button), .{.x=10,.y=10}, .{.w=-20,.h=30});

    try z.run();
}