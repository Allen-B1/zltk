usingnamespace @import("../core.zig");
const interface = @import("interface");

text: []const u8,

dirty: bool = true,
style: *const Style,

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

    try drawable.rect(.{.x=0,.y=0}, dimen, self.style.background);
    try drawable.text_align(state, .{.x=0,.y=0}, dimen, Align.MIDDLE, Align.MIDDLE, self.text, self.style.foreground, self.style.background, self.style.font);
}

pub const Impl = interface.impl(Widget, Button);