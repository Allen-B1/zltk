const interface = @import("interface");
const std = @import("std");
const zltk = @import("zltk");

pub fn main() !void {
    var z = try zltk.new(std.heap.c_allocator);

    var win = try zltk.Window.new(&z, zltk.Dimen{.w=500,.h=500});
    try win.set_title("hello world");
    try win.set_show(true);

    var button_style = zltk.Button.Style{
        .background = .{.r=0,.g=0,.b=255},
        .active_background = .{.r=0,.g=0,.b=255},
        .foreground = .{.r=255,.g=255,.b=255},
        .font = "6x13"
    };

    var button = zltk.Button{
        .pos = . {.x=20,.y=20},
        .dimen = .{.w=100,.h=30},
        .text = "Button",
        .style = &button_style
    };
    try win.widgets.append(interface.new(zltk.Widget, zltk.Button.Impl, &button));

    try z.run();
}