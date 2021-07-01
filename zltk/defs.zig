pub const Dimen = struct { w: u32, h: u32 };

pub const Pos = struct { x: i32, y: i32,
    pub fn add(p1: Pos, p2: Pos) Pos {
        return .{.x=p1.x+p2.x, .y=p1.y+p2.y};
    }

    pub fn sub(p1: Pos, p2: Pos) Pos {
        return .{.x=p1.x-p2.x, .y=p1.y-p2.y};
    }
};

pub const Color = struct { r: u8, g: u8, b: u8 };

pub const MouseButton = enum {
    LEFT,
    RIGHT,
    MIDDLE,
    SCROLL_UP,
    SCROLL_DOWN,
};

pub const Align = enum {
    START,
    MIDDLE,
    END
};