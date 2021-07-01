usingnamespace @import("../core.zig");
const interface = @import("interface");
const std = @import("std");

pub const RelDimen = struct { w: i32, h: i32,
    pub fn resolve(self: RelDimen, dimen: Dimen) Dimen {
        var out: Dimen = undefined;
        if (self.w < 0) {
            const sum = @intCast(i32, dimen.w) + self.w;
            if (sum < 0) { out.w = 0; }
            else { out.w = @intCast(u32, sum); }
        } else {
            out.w = @intCast(u32, self.w);
        }

        if (self.h < 0) {
            const sum = @intCast(i32, dimen.h) + self.h;
            if (sum < 0) { out.h = 0; }
            else { out.h = @intCast(u32, sum); }
        } else {
            out.h = @intCast(u32, self.h);
        }

        return out;
    }
};

pub const RelPos = struct { x: i32, y: i32,
    pub fn resolve(self: RelPos, dimen: Dimen) Pos {
        var out: Pos = Pos{.x=self.x, .y=self.y};

        if (out.x < 0) {
            out.x += @intCast(i32, dimen.w);
        }
        if (out.y < 0) {
            out.y += @intCast(i32, dimen.h);
        }

        return out;
    }
};

// do not use type
const RelPosDimen = struct {
    pos: RelPos,
    dimen: RelDimen,
};

const Fixed = @This();

widgets: std.ArrayList(Widget),
positions: std.ArrayList(RelPosDimen),
background: ?Color,
dirty: bool,

pub fn init(self: *Fixed, alloc: *std.mem.Allocator) void {
    self.widgets = std.ArrayList(Widget).init(alloc);
    self.positions = std.ArrayList(RelPosDimen).init(alloc);
    self.background = null;
    self.dirty = true;
}

pub fn dirty(self: *Fixed) bool {
    for (self.widgets.items) |widget| {
        if (widget.dirty()) return true;
    }
    return self.dirty;
}

pub fn draw(self: *Fixed, drawable: Drawable, draw_clean: bool, state: *State) anyerror!void { 
    if (self.background != null) {
        try drawable.rect(.{.x=0,.y=0}, drawable.dimen(), self.background.?);
    }

    for (self.widgets.items) |widget, i| {
        const geometry = self.positions.items[i];
        var range = Drawable.Range{.parent=drawable, .pos=geometry.pos.resolve(drawable.dimen()), .dimen=geometry.dimen.resolve(drawable.dimen())};
        try widget.draw(interface.new(Drawable, Drawable.RangeImpl, &range), draw_clean, state);
    }
}

pub fn add(self: *Fixed, widget: Widget, pos: RelPos, dimen: RelDimen) !void {
    try self.widgets.append(widget);
    try self.positions.append(.{.pos=pos,.dimen=dimen});
}

pub const Impl = interface.impl(Widget, Fixed);
