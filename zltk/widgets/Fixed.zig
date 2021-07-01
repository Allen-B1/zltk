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
dimen: Dimen,
dirty: bool,

pub fn init(self: *Fixed, alloc: *std.mem.Allocator) void {
    self.widgets = std.ArrayList(Widget).init(alloc);
    self.positions = std.ArrayList(RelPosDimen).init(alloc);
    self.background = null;
    self.dirty = true;
    self.dimen = .{.w=0,.h=0};
}

pub fn dirty(self: *Fixed) bool {
    for (self.widgets.items) |widget| {
        if (widget.dirty()) return true;
    }
    return self.dirty;
}

pub fn draw(self: *Fixed, drawable: Drawable, draw_clean: bool, state: *State) anyerror!void { 
    self.dimen = drawable.dimen();
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

fn find_widget(self: *Fixed, pos: Pos) ?usize {
    for (self.positions.items) |position,i| {
        const rpos = position.pos.resolve(self.dimen);
        const rdimen = position.dimen.resolve(self.dimen);

        if (pos.x > rpos.x and pos.x < rpos.x + @intCast(i32, rdimen.w) and
            pos.y > rpos.y and pos.y < rpos.y + @intCast(i32, rdimen.h)) {
            return i;
        }
    }

    return null;
}

pub fn onmousedown(self: *Fixed, pos: Pos) void {
    if (self.find_widget(pos)) |i| {
        const position = self.positions.items[i];
        const rpos = position.pos.resolve(self.dimen);
        const npos = pos.sub(rpos);
        
        self.widgets.items[i].onmousedown(npos);
    }
}

pub fn onmouseup(self: *Fixed, pos: Pos) void {
    if (self.find_widget(pos)) |i| {
        const position = self.positions.items[i];
        const rpos = position.pos.resolve(self.dimen);
        const npos = pos.sub(rpos);
        
        self.widgets.items[i].onmouseup(npos);
    }
}

pub fn onmousemove(self: *Fixed, from: Pos, to: Pos) void {
    const fromIdx = self.find_widget(from);
    const toIdx = self.find_widget(to);

    if (fromIdx != null and toIdx != null and fromIdx.? == toIdx.?) {
        const position = self.positions.items[fromIdx.?];
        const wpos = position.pos.resolve(self.dimen);
        self.widgets.items[fromIdx.?].onmousemove(from.sub(wpos), to.sub(wpos));
    } else {
        if (fromIdx) |idx| {
            const position = self.positions.items[idx];
            const wpos = position.pos.resolve(self.dimen);
            self.widgets.items[idx].onmouseexit(from.sub(wpos));
        }
        if (toIdx) |idx| {
            const position = self.positions.items[idx];
            const wpos = position.pos.resolve(self.dimen);
            self.widgets.items[idx].onmouseenter(to.sub(wpos));
        }
    }
}

pub fn onmouseenter(self: *Fixed, to: Pos) void {
    self.onmousemove(.{.x=-1, .y=-1}, to);
}
pub fn onmouseexit(self: *Fixed, from: Pos) void {
    self.onmousemove(from, .{.x=-1, .y=-1});
}

pub const Impl = interface.impl(Widget, Fixed);
