pub const layer = @import("layer/layer.zig");
pub usingnamespace @import("defs.zig");

const interface = @import("interface");
const std = @import("std");
const log = std.log;
const mem = std.mem;

pub const State = struct {
    allocator: *mem.Allocator,
    conn: layer.Connection,

    windows: std.AutoHashMap(layer.WindowID, *Window),

    // delay in the loop, in nanoseconds
    loop_interval: ?u32,

    pub fn new(alloc: *mem.Allocator) anyerror!State {
        var state: State  = undefined;
        state.conn = try layer.Connection.new();
        state.allocator = alloc;
        state.windows = std.AutoHashMap(layer.WindowID, *Window).init(alloc);
        state.loop_interval = null;
        return state;
    }

    pub fn destroy(self: *State) void {
        for (self.windows.valueIterator()) |value| {
            value.destroy();
        }

        self.windows.deinit();
        self.conn.destroy();
    }

    pub fn calc_text(self: *State, text: []const u8, font: []const u8) anyerror!Dimen {
        return self.conn.calc_text(text, font);
    }

    pub fn run(self: *State) anyerror!void {
        try self.conn.flush();

        while (true) {

            const event = self.conn.next_event(self.loop_interval);
            if (event != null) {
                blk: {
                    switch (event.?) {
                        layer.Event.expose => |expose| {
                            var window = self.windows.get(expose.window) orelse break :blk;
                            window.draw_all() catch |err| {
                                log.warn("error while drawing window {}: {}", .{window.id, err});
                                continue;
                            };
                        },
                        layer.Event.resize => |resize| {
                            var window = self.windows.get(resize.window) orelse break :blk;
                            window.dimen = resize.dimen;                            
                            window.draw_all() catch |err| {
                                log.warn("error while drawing window {}: {}", .{window.id, err});
                                continue;
                            };
                        },
                        else => {}
                    }
                }
            }

            var iterator = self.windows.valueIterator();
            while (iterator.next()) |window| {
                window.*.draw_dirty() catch |err| {
                    log.warn("error while drawing window {}: {}", .{window.*.id, err});
                    continue;
                };
            }

            try self.conn.flush();
        }
    }
};

pub const Window = struct {
    /// `state` and `id` should never be changed.
    state: *State,
    id: layer.WindowID,

    /// `title` should not be changed except through `set_title`.
    title: []const u8,
    // `dimen` should not be changed except by internal zltk code.
    dimen: Dimen,

    background: Color,

    widgets: std.ArrayList(Widget),

    pub fn new(state: *State, dimen: Dimen) anyerror!*Window {
        const windowID = try state.conn.window_new(layer.WindowOptions{.pos=Pos{.x=0,.y=0},.dimen=dimen});

        const window = try state.allocator.create(Window);
        window.state = state;
        window.id = windowID;
        window.title = &[_]u8{};
        window.dimen = dimen;
        window.background = Color{.r=255,.g=255,.b=255};
        window.widgets = std.ArrayList(Widget).init(state.allocator);
        _ = try state.windows.put(windowID, window);
        return window;
    }

    pub fn set_title(self: *Window, title: []const u8) anyerror!void {
        try self.state.conn.window_title(self.id, title);
        self.title = title;
    }

    pub fn set_show(self: *Window, show: bool) anyerror!void {
        try self.state.conn.window_show(self.id, show);
    }

    fn destroy(self: *Window) void {
        self.widgets.deinit();
        self.state.allocator.destroy(self);
    }

    pub fn draw_all(self: *Window) anyerror!void {
        const this = interface.new(Drawable, Drawable.WindowImpl, self);
        try this.rect(Pos{.x=0,.y=0}, self.dimen, self.background);

        for (self.widgets.items) |widget| {
            try widget.draw(this);
        }
    }

    pub fn draw_dirty(self: *Window) anyerror!void {
        const this = interface.new(Drawable, Drawable.WindowImpl, self);
        for (self.widgets.items) |widget| {
            if (widget.dirty()) {
                try widget.draw(this);
            }
        }
    }
};

pub const Drawable = struct {
    pub const Impl = struct {
        rect: fn (self: *interface.This, pos: Pos, dimen: Dimen, color: Color) anyerror!void,
        text: fn (self: *interface.This, pos: Pos, text: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void,
        dimen: fn (self: *interface.This) Dimen,
    };

    impl: *const Impl,
    data: *interface.This,

    pub fn rect(self: Drawable, pos: Pos, dimen_: Dimen, color: Color) anyerror!void {
        return self.impl.rect(self.data, pos, dimen_, color);
    }

    pub fn text (self: Drawable, pos: Pos, text_: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void {
        return self.impl.text(self.data, pos, text_, fg, bg, font);
    }

    pub fn dimen (self:Drawable) Dimen {
        return self.impl.dimen(self.data);
    }

    pub const WindowImpl = interface.impl(Drawable, struct {
        pub fn rect(self: *Window, pos: Pos, dimen_: Dimen, color: Color) anyerror!void {
            return self.state.conn.draw_rect(self.id, pos, dimen_, color);
        }
        pub fn text(self: *Window, pos: Pos, text_: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void {
            return self.state.conn.draw_text(self.id, pos, text_, fg, bg, font);
        }
        pub fn dimen(self: *Window) Dimen {
            return self.dimen; }
    });
};

pub const Widget = struct {
    pub const Impl = struct {
        dirty: fn (self: *interface.This) bool,
        draw: fn (self: *interface.This, drawable: Drawable) anyerror!void,
    };

    impl: *const Impl,
    data: *interface.This,

    pub fn dirty(self: Widget) bool {
        return self.impl.dirty(self.data);
    }

    pub fn draw(self: Widget, drawable: Drawable) anyerror!void {
        return self.impl.draw(self.data, drawable);
    }
};

pub const RelDimen = struct { w: i32, h: i32,
    pub fn resolve(self: RelDimen, dimen: Dimen) Dimen {
        var out: Dimen = undefined;
        if (self.w < 0) {
            const sum = dimen.w + self.w;
            if (sum < 0) { out.w = 0; }
            else { out.w = @intCast(u32, sum); }
        } else {
            out.w = @intCast(u32, self.w);
        }

        if (self.h < 0) {
            const sum = dimen.h + self.h;
            if (sum < 0) { out.h = 0; }
            else { out.h = @intCast(u32, sum); }
        } else {
            out.h = @intCast(u32, self.h);
        }
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
