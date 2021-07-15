const std = @import("std");

pub const Dimen = struct { w: u32, h: u32 };

pub const Pos = struct {
    x: i32,
    y: i32,
    pub fn add(p1: Pos, p2: Pos) Pos {
        return .{ .x = p1.x + p2.x, .y = p1.y + p2.y };
    }

    pub fn sub(p1: Pos, p2: Pos) Pos {
        return .{ .x = p1.x - p2.x, .y = p1.y - p2.y };
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

pub const Align = enum { START, MIDDLE, END };

pub fn Buf(comptime T: type, comptime size: usize) type {
    return struct {
        len: usize,
        data: [size]T,

        pub inline fn slice(self: *const @This()) []const T {
            return self.data[0..self.len];
        }

        pub fn append(self: *@This(), data: []const u8) void {
            if (data.len + self.len >= size) {
                std.mem.copy(u8, self.data[self.len..], data[0..size-self.len]);
                self.len = size;
            } else {
                std.mem.copy(u8, self.data[self.len..], data[0..]);
                self.len += data.len;
            }
        }
    };
}

pub const Key = struct {
    code: u8,
    chars: Buf(u8, 8),
    symbol: Buf(u8, 16),
};
