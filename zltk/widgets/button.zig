pub usingnamespace @import("../core.zig");
const interface = @import("interface");

pub const Button = struct {
    dimen: RelDimen,
    pos: RelPos,

    dirty_: bool = false,
    style: Style,

    pub const Style = struct {
        background: Color,
        active_background: Color
    };

    pub fn dirty(self: *Button) bool {
        return self.dirty_;
    }

    pub fn draw(self: *Button, drawable: Drawable) anyerror!void {
        
    }
};