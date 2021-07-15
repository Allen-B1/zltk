usingnamespace @import("../core.zig");
const interface = @import("interface");
const std = @import("std");

pub const Style = struct {
    border_width: u32,
    padding: u32,

    border: Color,
    focused_border: Color,

    background: Color,
    foreground: Color,
    font: []const u8,
};

text: Buf(u8, 256) = .{.len=0, .data=undefined},
style: *const Style,

oninput: ?fn (w: *@This()) void = null,
onenter: ?fn (w: *@This()) void = null,
onfocus: ?fn (w: *@This()) void = null,

dirty: bool = true,
focused: bool = false,

pub fn dirty(self: *@This()) bool {
    return self.dirty;
}

pub fn draw(self: *@This(), drawable: Drawable, draw_clean: bool, state: *State) anyerror!void {
    const dimen = drawable.dimen();
    const border = if (self.focused) self.style.focused_border else self.style.border;
    try drawable.rect(.{.x=0,.y=0}, dimen, border);
    try drawable.rect(
        .{.x=@intCast(i32, self.style.border_width), .y=@intCast(i32, self.style.border_width)},
        .{.w=dimen.w - 2*self.style.border_width, .h=dimen.h - 2*self.style.border_width},
        self.style.background);
    try drawable.text_align(state, .{ .x = @intCast(i32, self.style.padding), .y = 0 }, .{.w=dimen.w - 2*self.style.padding, .h=dimen.h}, Align.START, Align.MIDDLE, self.text.slice(), self.style.foreground, self.style.background, self.style.font);
}

pub fn onfocus(self: *@This(), focused: bool) void {
    if (self.focused != focused) {
        self.focused = focused;
        self.dirty = true;

        if (focused) {
            if (self.onfocus != null) 
                self.onfocus.?(self);
        }
    }
}

pub fn onkeydown(self: *@This(), key: Key) void {
    if (key.chars.len == 1 and key.chars.data[0] == 8) {
        if (self.text.len != 0) 
            self.text.len -= 1;
        self.dirty = true;

        if (self.oninput != null)
            self.oninput.?(self);
        return;
    }

    if (std.mem.eql(u8, key.symbol.slice(), "Enter")) {
        if (self.onenter != null)
            self.onenter.?(self);
        return;
    }

    // discard control characters
    if (key.chars.len == 0 or key.chars.data[0] < 0x20 or key.chars.data[0] == 0x7F) return;

    self.text.append(key.chars.slice());
    self.dirty = true;

    if (self.oninput != null)
        self.oninput.?(self);
}

pub const Impl = interface.impl(Widget, @This());