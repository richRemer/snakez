const std = @import("std");
pub const sdl3 = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

const Allocator = std.mem.Allocator;

pub fn getError() []const u8 {
    const ptr: [*c]const u8 = sdl3.SDL_GetError();
    var slice: []const u8 = &.{};

    slice.ptr = ptr;
    slice.len = std.mem.len(ptr);

    return slice;
}

pub fn init(flags: SubSystem) error{SDLError}!void {
    if (!sdl3.SDL_Init(@bitCast(flags))) {
        return error.SDLError;
    }
}

pub fn pollEvent() ?sdl3.SDL_Event {
    var event: sdl3.SDL_Event = undefined;

    if (sdl3.SDL_PollEvent(&event)) {
        return event;
    } else {
        return null;
    }
}

pub fn quit() void {
    sdl3.SDL_Quit();
}

pub fn setAppMetadata(
    name: [:0]const u8,
    version: [:0]const u8,
    ident: [:0]const u8,
) error{SDLError}!void {
    if (!sdl3.SDL_SetAppMetadata(name, version, ident)) {
        return error.SDLError;
    }
}

pub fn setMainReady() void {
    sdl3.SDL_SetMainReady();
}

pub const Gamepad = struct {
    ptr: *sdl3.SDL_Gamepad,

    /// Iterate over detected gamepads.  Resources used during iteration are
    /// cleaned up after the final iteration.  If iteration is not completed,
    /// call .flush() to ensure resources are cleaned up.
    pub const Iterator = struct {
        ids: [*c]sdl3.SDL_JoystickID,
        count: c_int,
        index: u8,

        pub fn init() error{SDLError}!Iterator {
            var count: c_int = 0;

            if (sdl3.SDL_GetGamepads(&count)) |ids| {
                return .{ .ids = ids, .count = count, .index = 0 };
            } else {
                return error.SDLError;
            }
        }

        pub fn next(this: *Iterator) ?sdl3.SDL_JoystickID {
            if (this.index < this.count) {
                const joystickId = this.ids[this.index];
                this.index += 1;
                return joystickId;
            } else {
                this.flush();
                return null;
            }
        }

        pub fn flush(this: *Iterator) void {
            this.index = @intCast(this.count);
            sdl3.SDL_free(this.ids);
        }
    };

    pub fn open(joystickId: sdl3.SDL_JoystickID) error{SDLError}!Gamepad {
        if (sdl3.SDL_OpenGamepad(joystickId)) |gamepad| {
            return .{ .ptr = gamepad };
        } else {
            return error.SDLError;
        }
    }

    pub fn close(this: Gamepad) void {
        sdl3.SDL_CloseGamepad(this.ptr);
    }

    pub fn firmwareVersion(this: Gamepad) u16 {
        return sdl3.SDL_GetGamepadFirmwareVersion(this.ptr);
    }

    pub fn id(this: Gamepad) sdl3.SDL_JoystickID {
        return sdl3.SDL_GetGamepadID(this.ptr);
    }

    pub fn name(this: Gamepad) []const u8 {
        const ptr: [*c]const u8 = sdl3.SDL_GetGamepadName(this.ptr);
        var slice: []const u8 = &.{};

        slice.ptr = @ptrCast(ptr);
        slice.len = std.mem.len(ptr);

        return slice;
    }
};

pub const Renderer = struct {
    ptr: *sdl3.SDL_Renderer,

    pub fn init(window: Window) error{SDLError}!Renderer {
        if (sdl3.SDL_CreateRenderer(window.ptr, null)) |renderer| {
            return .{ .ptr = renderer };
        } else {
            return error.SDLError;
        }
    }

    pub fn deinit(this: Renderer) void {
        sdl3.SDL_DestroyRenderer(this.ptr);
    }
};

pub const SubSystem = packed struct(u32) {
    reserved_4: u4 = 0,
    audio: bool = false,
    video: bool = false,
    reserved_3: u3 = 0,
    joystick: bool = false,
    reserved_2: u2 = 0,
    haptic: bool = false,
    gamepad: bool = false,
    events: bool = false,
    sensor: bool = false,
    camera: bool = false,
    reserved_15: u15 = 0,
};

pub const Window = struct {
    ptr: *sdl3.SDL_Window,

    pub const Flags = packed struct(u64) {
        fullscreen: bool = false,
        opengl: bool = false,
        occluded: bool = false,
        hidden: bool = false,
        borderless: bool = false,
        resizable: bool = false,
        minimized: bool = false,
        maximized: bool = false,
        mouse_grabbed: bool = false,
        input_focus: bool = false,
        mouse_focus: bool = false,
        external: bool = false,
        modal: bool = false,
        hipd: bool = false,
        mouse_capture: bool = false,
        mouse_relative_mode: bool = false,
        always_on_top: bool = false,
        utility: bool = false,
        tooltip: bool = false,
        popup_menu: bool = false,
        keyboard_grabbed: bool = false,
        reserved_7: u7 = 0,
        vulkan: bool = false,
        metal: bool = false,
        transparent: bool = false,
        not_focusable: bool = false,
        reserved_32: u32 = 0,
    };

    pub fn init(
        allocator: Allocator,
        title: []const u8,
        width: u16,
        height: u16,
        flags: Flags,
    ) error{ OutOfMemory, SDLError }!Window {
        const c_title = try std.mem.Allocator.dupeZ(allocator, u8, title);
        defer allocator.free(c_title);

        if (sdl3.SDL_CreateWindow(c_title, width, height, @bitCast(flags))) |window| {
            return .{ .ptr = window };
        } else {
            return error.SDLError;
        }
    }

    pub fn deinit(this: Window) void {
        sdl3.SDL_DestroyWindow(this.ptr);
    }
};
