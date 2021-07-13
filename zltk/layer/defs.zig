pub usingnamespace @import("../defs.zig");

pub const WindowID = u32;

pub const WindowOptions = struct {
    pos: Pos,
    dimen: Dimen,
};

pub const Event = union(enum) {
    expose: ExposeEvent,
    mouse_down: MouseDownEvent,
    mouse_up: MouseUpEvent,
    mouse_move: MouseMoveEvent,
    mouse_enter: MouseEnterEvent,
    mouse_exit: MouseExitEvent,
    resize: ResizeEvent,
    close: CloseEvent,
    key_down: KeyDownEvent,
    key_up: KeyUpEvent,
};

pub const ExposeEvent = struct {
    window: WindowID,
    pos: Pos,
    dimen: Dimen,
};

pub const MouseDownEvent = struct {
    window: WindowID,
    pos: Pos,
    button: MouseButton,
};

pub const MouseUpEvent = MouseDownEvent;

pub const MouseMoveEvent = struct {
    window: WindowID,
    pos: Pos,
};

pub const MouseEnterEvent = struct {
    window: WindowID,
    pos: Pos,
};

pub const MouseExitEvent = MouseEnterEvent;

pub const ResizeEvent = struct {
    window: WindowID,
    dimen: Dimen,
};

pub const CloseEvent = struct {
    window: WindowID,
};

pub const KeyDownEvent = struct {
    window: WindowID,
    key: Key,
};

pub const KeyUpEvent = KeyDownEvent;
