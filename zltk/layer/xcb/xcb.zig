const c = @import("c.zig");
usingnamespace @import("../defs.zig");
const std = @import("std");
const log = std.log;

const time = @import("std").time;

pub const Connection = struct {
    conn: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    colormap: std.AutoHashMap(Color, u32),

    pub fn new() anyerror!Connection {
        var screenp: c_int = 0;
        const conn = c.xcb_connect(null, null);
        if (conn == null) {
            return error.XCBCouldNotConnect;
        }
        const setup = c.xcb_get_setup(conn);
        if (setup == null) {
            return error.XCBScreenNotFound;
        }
        const screen = c.xcb_setup_roots_iterator(setup).data;
        if (screen == null) {
            return error.XCBScreenNotFound;
        }

        var colormap = std.AutoHashMap(Color, u32).init(std.heap.c_allocator);
        try colormap.put(Color{ .r = 255, .g = 255, .b = 255 }, screen.*.white_pixel);
        try colormap.put(Color{ .r = 0, .g = 0, .b = 0 }, screen.*.black_pixel);

        return Connection{ .conn = conn.?, .screen = screen.?, .colormap = colormap };
    }

    pub fn destroy(x: *Connection) anyerror!void {
        x.colormap.deinit();
        c.xcb_disconnect(x.conn);
    }

    pub fn window_new(x: *Connection, opts: WindowOptions) anyerror!WindowID {
        const winID = c.xcb_generate_id(x.conn);
        const values = [_]u32{
            c.XCB_EVENT_MASK_EXPOSURE | c.XCB_EVENT_MASK_BUTTON_PRESS | c.XCB_EVENT_MASK_BUTTON_RELEASE |
            c.XCB_EVENT_MASK_POINTER_MOTION | c.XCB_EVENT_MASK_BUTTON_MOTION | c.XCB_EVENT_MASK_ENTER_WINDOW | c.XCB_EVENT_MASK_LEAVE_WINDOW |
            c.XCB_EVENT_MASK_STRUCTURE_NOTIFY };

        _ = c.xcb_create_window(x.conn, c.XCB_COPY_FROM_PARENT, winID, x.screen.root, @intCast(i16, opts.pos.x), @intCast(i16, opts.pos.y), @intCast(u16, opts.dimen.w), @intCast(u16, opts.dimen.h), 0, c.XCB_WINDOW_CLASS_INPUT_OUTPUT, x.screen.root_visual,
            c.XCB_CW_EVENT_MASK, &values);

        return @as(u32, winID);
    }

    pub fn window_title(x: *Connection, win: WindowID, title: []const u8) anyerror!void {
        _ = c.xcb_change_property(x.conn, c.XCB_PROP_MODE_REPLACE, win, c.XCB_ATOM_WM_NAME, c.XCB_ATOM_STRING, 8, @intCast(u32, title.len), title.ptr);
    }

    pub fn draw_rect(x: *Connection, win: WindowID, pos: Pos, dimen: Dimen, clr: Color) anyerror!void {
        const gc = c.xcb_generate_id(x.conn);
        const pixel = try x.color_get(clr);
        _ = c.xcb_create_gc(x.conn, gc, win, c.XCB_GC_FOREGROUND, &pixel);

        const rect: c.xcb_rectangle_t = c.xcb_rectangle_t{ .x = @intCast(i16, pos.x), .y = @intCast(i16, pos.y), .width = @intCast(u16, dimen.w), .height = @intCast(u16, dimen.h) };
        _ = c.xcb_poly_fill_rectangle(x.conn, win, gc, 1, &rect);

        _ = c.xcb_free_gc(x.conn, gc);
    }

    pub fn calc_text(x: *Connection, text: []const u8, font: []const u8) anyerror!Dimen {
        var size: Dimen = blk: {
            const idx = std.mem.indexOf(u8, font, "x");
            if (idx == null) {
                break :blk Dimen{.w=6,.h=13};
            }

            const w = try std.fmt.parseUnsigned(u8, font[0..idx.?], 10);
            const h = try std.fmt.parseUnsigned(u8, font[idx.?+1..], 10);
            break :blk Dimen{.w=w, .h=h};
        };

        size.w *= @intCast(u32, text.len);
        return size;
    }

    pub fn draw_text(x: *Connection, win: WindowID, pos: Pos, text: []const u8, fg: Color, bg: Color, font: []const u8) anyerror!void {
        const fontID = c.xcb_generate_id(x.conn);
        _ = c.xcb_open_font(x.conn, fontID, @intCast(u16, font.len), font.ptr);

        const gcID = c.xcb_generate_id(x.conn);
        const values = [_]u32{try x.color_get(fg), try x.color_get(bg), fontID};
        _ = c.xcb_create_gc(x.conn, gcID, win, c.XCB_GC_FOREGROUND | c.XCB_GC_BACKGROUND | c.XCB_GC_FONT, &values);
        _ = c.xcb_close_font(x.conn, fontID);

        const dimen = try x.calc_text(text, font);
        _ = c.xcb_image_text_8_checked(x.conn, @intCast(u8, text.len), win, gcID, @intCast(i16, pos.x), @intCast(i16, pos.y+@intCast(i32, dimen.h)), text.ptr);
    }

    pub fn window_show(x: *Connection, win: WindowID, show: bool) anyerror!void {
        if (show) {
            _ = c.xcb_map_window(x.conn, win);
        } else {
            _ = c.xcb_unmap_window(x.conn, win);
        }
    }

    fn color_get(x: *Connection, clr: Color) !u32 {
        return x.colormap.get(clr) orelse blk: {
            const cookie = c.xcb_alloc_color(x.conn, x.screen.default_colormap, @as(u16, clr.r) * 257, @as(u16, clr.g) * 257, @as(u16, clr.b) * 257);
            const reply: *c.xcb_alloc_color_reply_t = c.xcb_alloc_color_reply(x.conn, cookie, null) orelse return error.XCBAllocColorFail;
            const pixel = reply.pixel;
            c.free(reply);

            try x.colormap.put(clr, pixel);
            break :blk pixel;
        };
    }

    pub fn next_event(x: *Connection, nanosecs: ?u32) ?Event {
        var evt: ?*c.xcb_generic_event_t = null;
        if (nanosecs == null) {
            evt = c.xcb_wait_for_event(x.conn);
        } else if (nanosecs.? == 0) {
            evt = c.xcb_poll_for_event(x.conn);
        } else {
            const fd = c.xcb_get_file_descriptor(x.conn);
            const timeout = c.struct_timespec{ .tv_sec = nanosecs.? / time.ns_per_s, .tv_nsec = nanosecs.? % time.ns_per_s };

            var fds: c.fd_set = undefined;
            c.alt_FD_ZERO(&fds);
            c.alt_FD_SET(fd, &fds);

            _ = c.pselect(fd + 1, &fds, null, null, &timeout, null);

            evt = c.xcb_poll_for_event(x.conn);
        }

        if (evt == null) return null;

        const res = switch (evt.?.response_type & ~@as(u32, 0x80)) {
            c.XCB_EXPOSE => expose:{
                var revt = @ptrCast(*c.xcb_expose_event_t, evt);

                var resp: ExposeEvent = undefined;
                resp.window = revt.window;
                resp.pos = Pos{ .x = revt.x, .y = revt.y };
                resp.dimen = Dimen{ .w = revt.width, .h = revt.height };
                break :expose Event{ .expose = resp };
            },
            c.XCB_BUTTON_PRESS, c.XCB_BUTTON_RELEASE => mousedown:{
                var revt = @ptrCast(*c.xcb_button_press_event_t, evt);

                var resp: MouseDownEvent = undefined;
                resp.window = revt.event;
                resp.pos = Pos{ .x = @intCast(i32, revt.event_x), .y = @intCast(i32, revt.event_y) };
                resp.button = switch (revt.detail) {
                    1 => MouseButton.LEFT,
                    2 => MouseButton.MIDDLE,
                    3 => MouseButton.RIGHT,
                    4 => MouseButton.SCROLL_UP,
                    5 => MouseButton.SCROLL_DOWN,
                    else => MouseButton.LEFT,
                };

                if (revt.response_type & ~@as(u32, 0x80) == c.XCB_BUTTON_PRESS) {
                    break :mousedown Event{ .mouse_down = resp };
                } else {
                    break :mousedown Event{ .mouse_up = resp };
                }
            },
            c.XCB_MOTION_NOTIFY => mousemove: {
                var revt = @ptrCast(*c.xcb_motion_notify_event_t, evt);

                var resp: MouseMoveEvent = undefined;
                resp.window = revt.event;
                resp.pos = Pos{.x = @intCast(i32, revt.event_x), .y = @intCast(i32, revt.event_y)};
                break :mousemove Event{.mouse_move=resp};
            },
            c.XCB_ENTER_NOTIFY, c.XCB_LEAVE_NOTIFY => mouseenter: {
                var revt = @ptrCast(*c.xcb_leave_notify_event_t, evt);

                var resp: MouseEnterEvent = undefined;
                resp.window = revt.event;
                resp.pos = Pos{.x = @intCast(i32, revt.event_x), .y = @intCast(i32, revt.event_y)};
                if (revt.response_type & ~@as(u32, 0x80) == c.XCB_ENTER_NOTIFY) {
                    break :mouseenter Event{ .mouse_enter = resp };
                } else {
                    break :mouseenter Event{ .mouse_exit = resp };
                }
            },
            c.XCB_CONFIGURE_NOTIFY => resize: {
                var revt = @ptrCast(*c.xcb_configure_notify_event_t, evt);

                var resp: ResizeEvent = undefined;
                resp.window = revt.window;
                resp.dimen = Dimen{.w=revt.width, .h=revt.height};
                break :resize Event{.resize=resp};
            }, 
            else => null,
        };
        c.free(evt);
        return res;
    }

    pub fn flush(x: *Connection) anyerror!void {
        _ = c.xcb_flush(x.conn);
    }
};
