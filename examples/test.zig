const interface = @import("interface");
const std = @import("std");
const zltk = @import("zltk");

const BLUE = .{.r=0x03, .g=0xa9, .b=0xf4};
const BLUE_D = .{.r=0x00,.g=0x7a, .b=0xc1};
const YELLOW = .{.r=0xff,.g=0xea,.b=0x00};
const YELLOW_D = .{.r=0xe6,.g=0xd2,.b=0x00};
const FONT = "6x13";

const button_style_1 = zltk.Button.Style{ .background = BLUE, .active_background = BLUE_D, .foreground = .{ .r = 255, .g = 255, .b = 255 }, .font = FONT };

const button_style_2 = zltk.Button.Style{ .background = YELLOW, .active_background = YELLOW_D, .foreground = .{ .r = 0x11, .g = 0x11, .b = 0x11 }, .font = FONT };

const entry_style = zltk.Entry.Style{
    .border_width = 2,
    .padding = 10,
    .border = .{.r=0x80,.g=0x80,.b=0x80},
    .focused_border = BLUE,
    .background = .{.r=0xff,.g=0xff,.b=0xff},
    .foreground = .{.r=0x11,.g=0x11,.b=0x11},
    .font = FONT,
};

pub fn main() !void {
    var z = try zltk.new(std.heap.c_allocator);

    var win = try zltk.Window.new(&z, zltk.Dimen{ .w = 200, .h = 200 });
    try win.set_title("two rectangles");
    try win.set_show(true);

    var root: zltk.Fixed = undefined;
    root.init(std.heap.c_allocator);
    root.background = .{ .r = 255, .g = 255, .b = 255 };
    try win.add(zltk.Widget.new(&root));

    var button = zltk.Button{ .text = "A", .style = &button_style_1 };
    try root.add(zltk.Widget.new(&button), .{ .x = 10, .y = 10 }, .{ .w = -20, .h = 30 });

    var button2 = zltk.Button{ .text = "B", .style = &button_style_2 };
    try root.add(zltk.Widget.new(&button2), .{ .x = 10, .y = 50 }, .{ .w = -20, .h = -100 });

    var input = zltk.Entry{.style = &entry_style};
    try root.add(zltk.Widget.new(&input), .{.x=10, .y=-40}, .{.w=-20,.h=30});

    try z.run();
}
