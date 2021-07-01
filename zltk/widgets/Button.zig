usingnamespace @import("../core.zig");
const interface = @import("interface");
const std = @import("std");

text: []const u8,
style: *const Style,

onclick: ?fn()void = null,

active: bool = false,
dirty: bool = true,

pub const Style = struct {
    background: Color,
    active_background: Color,
    foreground: Color,
    font: []const u8,
};

const Button = @This();

pub fn dirty(self: *Button) bool {
    return self.dirty;
}

pub fn draw(self: *Button, drawable: Drawable, draw_clean: bool, state: *State) anyerror!void {
    const dimen = drawable.dimen();

    const bg = if (self.active) self.style.active_background else self.style.background;
    try drawable.rect(.{.x=0,.y=0}, dimen, bg);
    try drawable.text_align(state, .{.x=0,.y=0}, dimen, Align.MIDDLE, Align.MIDDLE, self.text, self.style.foreground, bg, self.style.font);
}

pub fn onmousedown(self: *Button, pos: Pos) void {
    self.active = true;
    self.dirty = true;
}

pub fn onmouseexit(self: *Button, from: Pos) void {
    if (self.active) {
        self.active = false;
        self.dirty = true;
    }
}

pub fn onmouseup(self: *Button, pos: Pos) void {
    if (self.active) {
        self.active = false;
        self.dirty = true;

        if (self.onclick) |f| {
            f();
        }
    }
}

pub const Impl = interface.impl(Widget, Button);