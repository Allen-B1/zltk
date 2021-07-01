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
                            window.draw(true) catch |err| {
                                log.warn("error while drawing window {}: {}", .{window.id, err});
                                continue;
                            };
                        },
                        layer.Event.resize => |resize| {
                            var window = self.windows.get(resize.window) orelse break :blk;
                            window.dimen = resize.dimen;                            
                            window.draw(true) catch |err| {
                                log.warn("error while drawing window {}: {}", .{window.id, err});
                                continue;
                            };
                        },
                        layer.Event.mouse_down => |evt| {
                            var window = self.windows.get(evt.window) orelse break :blk;
                            if (window.widget) |w| {
                                w.onmousedown(evt.pos);
                            }
                        },
                        layer.Event.mouse_up => |evt| {
                            var window = self.windows.get(evt.window) orelse break :blk;
                            if (window.widget) |w| {
                                w.onmouseup(evt.pos);
                            }
                        },
                        layer.Event.mouse_move => |evt| {
                            var window = self.windows.get(evt.window) orelse break :blk;
                            if (window.widget) |w| {
                                w.onmousemove(window.mouse, evt.pos);
                            }
                            window.mouse = evt.pos;
                        },
                        layer.Event.mouse_enter => |evt| {
                            var window = self.windows.get(evt.window) orelse break :blk;
                            if (window.widget) |w| {
                                w.onmouseenter(evt.pos);
                            }
                            window.mouse = evt.pos;
                        },
                        layer.Event.mouse_exit => |evt| {
                            var window = self.windows.get(evt.window) orelse break :blk;
                            if (window.widget) |w| {
                                w.onmouseenter(window.mouse);
                            }
                            window.mouse = .{.x=-1,.y=-1};
                        },
                        else => {}
                    }
                }
            }

            var iterator = self.windows.valueIterator();
            while (iterator.next()) |window| {
                window.*.draw(false) catch |err| {
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

    widget: ?Widget,

    mouse: Pos,

    pub fn new(state: *State, dimen: Dimen) anyerror!*Window {
        const windowID = try state.conn.window_new(layer.WindowOptions{.pos=Pos{.x=0,.y=0},.dimen=dimen});

        const window = try state.allocator.create(Window);
        window.state = state;
        window.id = windowID;
        window.title = &[_]u8{};
        window.dimen = dimen;
        window.widget = null;
        window.mouse = .{.x=-1,.y=-1};
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

    pub fn add(self: *Window, widget: Widget) !void {
        if (self.widget == null) {
            self.widget = widget;
        } else {
            return error.WidgetAlreadyExists;
        }
    }

    pub fn draw(self: *Window, draw_clean: bool) anyerror!void {
        if (self.widget != null) {
            return self.widget.?.draw(interface.new(Drawable, Drawable.WindowImpl, self), draw_clean, self.state);
        }
    }

    fn destroy(self: *Window) void {
        self.widgets.deinit();
        self.state.allocator.destroy(self);
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

    pub fn text_align (self: Drawable, state: *State, pos_: Pos, dimen_: Dimen, halign: Align, valign: Align,
        text_: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void {
        const tdimen = try state.calc_text(text_, font);
        var pos = pos_;

        if (halign == Align.END) {
            pos.x += @intCast(i32, dimen_.w) - @intCast(i32, tdimen.w);
        }
        if (halign == Align.MIDDLE) {
            pos.x += @divTrunc(@intCast(i32, dimen_.w) - @intCast(i32, tdimen.w), 2);
        }
        if (valign == Align.END) {
            pos.y += @intCast(i32, dimen_.h) - @intCast(i32, tdimen.h);
        }
        if (valign == Align.MIDDLE) {
            pos.y += @divTrunc(@intCast(i32, dimen_.h) - @intCast(i32, tdimen.h), 2);
        }
    
        return self.text(pos, text_, fg, bg, font);
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

    pub const Range = struct {
        parent: Drawable,

        pos: Pos,
        dimen: Dimen,

        fn resolve_pos(self: *Range, pos: Pos) Pos {
            return Pos{.x=pos.x+self.pos.x, .y=pos.y+self.pos.y};
        }

        pub fn rect(self: *Range, pos_: Pos, dimen_: Dimen, color: Color) anyerror!void {
            return self.parent.rect(self.resolve_pos(pos_), dimen_, color);
        }
        pub fn text(self: *Range, pos: Pos, text_: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void {
            return self.parent.text(self.resolve_pos(pos), text_, fg, bg, font);
        }
        pub fn dimen(self: *Range) Dimen {
            return self.dimen;
        }
    };

    pub const RangeImpl = interface.impl(Drawable, Range);
};

pub const Widget = struct {
    pub const Impl = struct {
        dirty: fn (self: *interface.This) bool,
        draw: fn (self: *interface.This, drawable: Drawable, draw_clean: bool, state: *State) anyerror!void,

        onmousedown: ?fn (self: *interface.This, pos: Pos) void,
        onmouseup: ?fn (self: *interface.This, pos: Pos) void,
        onmousemove: ?fn (self: *interface.This, from: Pos, to: Pos) void,
        onmouseenter: ?fn (self: *interface.This, to: Pos) void,
        onmouseexit: ?fn (self: *interface.This, from: Pos) void,
    };

    impl: *const Impl,
    data: *interface.This,

    pub fn dirty(self: Widget) bool {
        return self.impl.dirty(self.data);
    }

    pub fn draw(self: Widget, drawable: Drawable, draw_clean: bool, state: *State) anyerror!void {
        return self.impl.draw(self.data, drawable, draw_clean, state);
    }

    pub fn onmousedown(self: Widget, pos: Pos) void {
        if (self.impl.onmousedown != null) {
            self.impl.onmousedown.?(self.data, pos);
        } else {
            std.log.info("bruh", .{});
        }
    }
    pub fn onmouseup(self: Widget, pos: Pos) void {
        if (self.impl.onmouseup != null)
            self.impl.onmouseup.?(self.data, pos);
    }
    pub fn onmousemove(self: Widget, from: Pos, to: Pos) void {
        if (self.impl.onmousemove != null)
            self.impl.onmousemove.?(self.data, from, to);
    }
    pub fn onmouseenter(self: Widget, to: Pos) void {
        if (self.impl.onmouseenter != null)
            self.impl.onmouseenter.?(self.data, to);
    }
    pub fn onmouseexit(self: Widget, from: Pos) void {
        if (self.impl.onmouseexit != null)
            self.impl.onmouseexit.?(self.data, from);
    }

    /// Creates a widget from the given parameter. `widget` should be a pointer.
    /// Equivalent to `interface.new(zltk.Widget, @TypeOf(widget.*).Impl, widget).
    pub fn new(widget: anytype) Widget {
        return interface.new(Widget, @TypeOf(widget.*).Impl, widget);
    }
};
