pub usingnamespace @import("../core.zig");
const interface = @import("interface");

pub const Button = struct {
    dimen: RelDimen,
    pos: RelPos,

    text: []const u8,

    dirty_: bool = false,
    style: *const Style,

    pub const Style = struct {
        background: Color,
        active_background: Color,
        foreground: Color,
        font: []const u8,
    };

    pub fn dirty(self: *Button) bool {
        return self.dirty_;
    }

    pub fn draw(self: *Button, drawable: Drawable, state: *State) anyerror!void {
        const pdimen = drawable.dimen();
        const adimen = self.dimen.resolve(pdimen);
        const apos = self.pos.resolve(pdimen);

        try drawable.rect(apos, adimen, self.style.background);
        try drawable.text_align(state, apos, adimen, Align.MIDDLE, Align.MIDDLE, self.text, self.style.foreground, self.style.background, self.style.font);
    }

    pub const Impl = interface.impl(Widget, Button);
};