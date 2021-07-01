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
    try win.add(zltk.Widget.new(&root));

    const button_style = zltk.Button.Style{
        .background = .{.r=0,.g=0,.b=255},
        .active_background = .{.r=0,.g=0,.b=255},
        .foreground = .{.r=255,.g=255,.b=255},
        .font = "6x13"
    };

    var button = zltk.Button{
        .text = "A",
        .style = &button_style
    };
    try root.add(zltk.Widget.new(&button), .{.x=10,.y=10}, .{.w=-20,.h=30});

    var button2 = zltk.Button{
        .text = "B",
        .style = &button_style
    };
    try root.add(zltk.Widget.new(&button2), .{.x=10,.y=50}, .{.w=-20,.h=-60});


    try z.run();
}