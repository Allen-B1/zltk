const interface = @import("interface");
const std = @import("std");
const zltk = @import("zltk");

const button_style_1 = zltk.Button.Style{
    .background = .{.r=0x21,.g=0x96,.b=0xf3},
    .active_background = .{.r=0x19,.g=0x76,.b=0xd2},
    .foreground = .{.r=255,.g=255,.b=255},
    .font = "6x13"
};

const button_style_2 = zltk.Button.Style{
    .background = .{.r=0xff,.g=0xeb,.b=0x3b},
    .active_background = .{.r=0xfb,.g=0xc0,.b=0x2d},
    .foreground = .{.r=0x11,.g=0x11,.b=0x11},
    .font = "6x13"
};

pub fn main() !void {
    var z = try zltk.new(std.heap.c_allocator);

    var win = try zltk.Window.new(&z, zltk.Dimen{.w=200,.h=200});
    try win.set_title("two rectangles");
    try win.set_show(true);

    var root: zltk.Fixed = undefined;
    root.init(std.heap.c_allocator);
    root.background = .{.r=255,.g=255,.b=255};
    try win.add(zltk.Widget.new(&root));

    var button = zltk.Button{
        .text = "A",
        .style = &button_style_1
    };
    try root.add(zltk.Widget.new(&button), .{.x=10,.y=10}, .{.w=-20,.h=30});

    var button2 = zltk.Button{
        .text = "B",
        .style = &button_style_2
    };
    try root.add(zltk.Widget.new(&button2), .{.x=10,.y=50}, .{.w=-20,.h=-60});


    try z.run();
}