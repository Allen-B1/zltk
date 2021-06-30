pub const Dimen = struct { w: u32, h: u32 };
pub const Pos = struct { x: i32, y: i32 };

pub const Color = struct { r: u8, g: u8, b: u8 };

pub const MouseButton = enum {
    LEFT,
    RIGHT,
    MIDDLE,
    SCROLL_UP,
    SCROLL_DOWN,
};