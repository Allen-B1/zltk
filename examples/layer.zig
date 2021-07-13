const layer = @import("zltk").layer;
const std = @import("std");
const time = std.time;
const log = std.log;

pub fn main() !void {
    var c = try layer.Connection.new();
    const bg = layer.Color{ .r = 255, .g = 255, .b = 0 };
    const win = try c.window_new(layer.WindowOptions{ .dimen = layer.Dimen{ .w = 500, .h = 200 }, .pos = layer.Pos{ .x = 0, .y = 0 } });

    try c.window_title(win, "Hello world!");
    try c.window_show(win, true);
    try c.flush();

    var dimen = layer.Dimen{ .w = 0, .h = 0 };
    while (true) {
        const evt = c.next_event(null) orelse continue;
        switch (evt) {
            layer.Event.expose => |e| {
                try c.draw_rect(win, layer.Pos{ .x = 0, .y = 0 }, dimen, layer.Color{ .r = 255, .g = 255, .b = 0 });
                try c.draw_rect(win, layer.Pos{ .x = 10, .y = 10 }, layer.Dimen{ .w = 500, .h = 350 }, layer.Color{ .r = 0, .g = 0, .b = 255 });
                try c.draw_text(win, layer.Pos{ .x = 10, .y = 10 }, "hello world!", layer.Color{ .r = 255, .g = 0, .b = 0 }, layer.Color{ .r = 255, .g = 255, .b = 0 }, "6x13");
                try c.flush();
            },
            layer.Event.mouse_down => |e| {
                log.info("{}", .{e.button});
            },
            layer.Event.mouse_enter => |e| {
                log.info("mouse enter", .{});
            },
            layer.Event.mouse_exit => |e| {
                log.info("mouse exit", .{});
            },
            layer.Event.resize => |e| {
                dimen = e.dimen;
                log.info("resize: {}x{}", .{ e.dimen.w, e.dimen.h });
            },
            layer.Event.close => |e| {
                log.info("close", .{});
            },
            layer.Event.key_down => |e| {
                log.info("keydown: {} | {s} | {s}", .{ e.key.code, e.key.chars.data[0..e.key.chars.len], e.key.symbol.data[0..e.key.symbol.len] });
            },
            else => {},
        }
    }
}
