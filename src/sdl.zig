const std = @import("std");
const data = @import("data.zig");
const mem = std.mem;
const Pair = data.Pair;
const Quad = data.Quad;
const Allocator = mem.Allocator;

pub const sdl3 = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

pub fn getError() []const u8 {
    const ptr: [*c]const u8 = sdl3.SDL_GetError();
    var slice: []const u8 = &.{};

    slice.ptr = ptr;
    slice.len = mem.len(ptr);

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
        slice.len = mem.len(ptr);

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

    pub fn clear(this: Renderer) !void {
        if (!sdl3.SDL_RenderClear(this.ptr)) {
            return error.SDLError;
        }
    }

    pub fn getCurrentOutputSize(this: Renderer) Pair(c_int) {
        var size: Pair(c_int) = undefined;

        if (!sdl3.SDL_GetCurrentRenderOutputSize(this.ptr, &size.@"0", &size.@"1")) {
            return .{ 0, 0 };
        }

        return size;
    }

    pub fn getOutputSize(this: Renderer) Pair(c_int) {
        var size: Pair(c_int) = undefined;

        if (!sdl3.SDL_GetRenderOutputSize(this.ptr, &size.@"0", &size.@"1")) {
            return .{ 0, 0 };
        }

        return size;
    }

    pub fn point(this: Renderer, pos: Pair(f32)) !void {
        if (!sdl3.SDL_RenderPoint(this.ptr, pos.@"0", pos.@"1")) {
            return error.SDLError;
        }
    }

    pub fn present(this: Renderer) !void {
        if (!sdl3.SDL_RenderPresent(this.ptr)) {
            return error.SDLError;
        }
    }

    pub fn renderLine(this: Renderer, p1: Pair(f32), p2: Pair(f32)) !void {
        if (!sdl3.SDL_RenderLine(this.ptr, p1.@"0", p1.@"1", p2.@"0", p2.@"1")) {
            return error.SDLError;
        }
    }

    pub fn renderRect(this: Renderer, rect: Quad(f32)) !void {
        const sdl_rect = frect(rect);

        if (!sdl3.SDL_RenderRect(this.ptr, &sdl_rect)) {
            return error.SDLError;
        }
    }

    pub fn renderTexture(
        this: Renderer,
        texture: Texture,
        src: Quad(f32),
        dst: Quad(f32),
    ) !void {
        const src_rect = frect(src);
        const dst_rect = frect(dst);

        if (!sdl3.SDL_RenderTexture(this.ptr, texture.ptr, &src_rect, &dst_rect)) {
            return error.SDLError;
        }
    }

    pub fn setDrawColor(this: Renderer, r: u8, g: u8, b: u8, a: u8) !void {
        if (!sdl3.SDL_SetRenderDrawColor(this.ptr, r, g, b, a)) {
            return error.SDLError;
        }
    }

    pub fn setTarget(this: Renderer, texture: Texture) !void {
        if (!sdl3.SDL_SetRenderTarget(this.ptr, texture.ptr)) {
            return error.SDLError;
        }
    }

    pub fn setTargetDefault(this: Renderer) !void {
        if (!sdl3.SDL_SetRenderTarget(this.ptr, null)) {
            return error.SDLError;
        }
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

pub const Texture = struct {
    ptr: *sdl3.SDL_Texture,

    pub const Access = enum(c_int) {
        static = sdl3.SDL_TEXTUREACCESS_STATIC,
        streaming = sdl3.SDL_TEXTUREACCESS_STREAMING,
        target = sdl3.SDL_TEXTUREACCESS_TARGET,
    };

    pub const PixelFormat = enum(c_uint) {
        unknown = sdl3.SDL_PIXELFORMAT_UNKNOWN,
        index1lsb = sdl3.SDL_PIXELFORMAT_INDEX1LSB,
        index1msb = sdl3.SDL_PIXELFORMAT_INDEX1MSB,
        index2lsb = sdl3.SDL_PIXELFORMAT_INDEX2LSB,
        index2msb = sdl3.SDL_PIXELFORMAT_INDEX2MSB,
        index4lsb = sdl3.SDL_PIXELFORMAT_INDEX4LSB,
        index4msb = sdl3.SDL_PIXELFORMAT_INDEX4MSB,
        index8 = sdl3.SDL_PIXELFORMAT_INDEX8,
        rgb332 = sdl3.SDL_PIXELFORMAT_RGB332,
        xrgb4444 = sdl3.SDL_PIXELFORMAT_XRGB4444,
        xbgr4444 = sdl3.SDL_PIXELFORMAT_XBGR4444,
        xrgb1555 = sdl3.SDL_PIXELFORMAT_XRGB1555,
        xbgr1555 = sdl3.SDL_PIXELFORMAT_XBGR1555,
        argb4444 = sdl3.SDL_PIXELFORMAT_ARGB4444,
        rgba4444 = sdl3.SDL_PIXELFORMAT_RGBA4444,
        abgr4444 = sdl3.SDL_PIXELFORMAT_ABGR4444,
        bgra4444 = sdl3.SDL_PIXELFORMAT_BGRA4444,
        argb1555 = sdl3.SDL_PIXELFORMAT_ARGB1555,
        rgba5551 = sdl3.SDL_PIXELFORMAT_RGBA5551,
        abgr1555 = sdl3.SDL_PIXELFORMAT_ABGR1555,
        bgra5551 = sdl3.SDL_PIXELFORMAT_BGRA5551,
        rgb565 = sdl3.SDL_PIXELFORMAT_RGB565,
        bgr565 = sdl3.SDL_PIXELFORMAT_BGR565,
        rgb24 = sdl3.SDL_PIXELFORMAT_RGB24,
        bgr24 = sdl3.SDL_PIXELFORMAT_BGR24,
        xrgb8888 = sdl3.SDL_PIXELFORMAT_XRGB8888,
        rgbx8888 = sdl3.SDL_PIXELFORMAT_RGBX8888,
        xbgr8888 = sdl3.SDL_PIXELFORMAT_XBGR8888,
        bgrx8888 = sdl3.SDL_PIXELFORMAT_BGRX8888,
        argb8888 = sdl3.SDL_PIXELFORMAT_ARGB8888,
        rgba8888 = sdl3.SDL_PIXELFORMAT_RGBA8888,
        abgr8888 = sdl3.SDL_PIXELFORMAT_ABGR8888,
        bgra8888 = sdl3.SDL_PIXELFORMAT_BGRA8888,
        xrgb2101010 = sdl3.SDL_PIXELFORMAT_XRGB2101010,
        xbgr2101010 = sdl3.SDL_PIXELFORMAT_XBGR2101010,
        argb2101010 = sdl3.SDL_PIXELFORMAT_ARGB2101010,
        abgr2101010 = sdl3.SDL_PIXELFORMAT_ABGR2101010,
        rgb48 = sdl3.SDL_PIXELFORMAT_RGB48,
        bgr48 = sdl3.SDL_PIXELFORMAT_BGR48,
        rgba64 = sdl3.SDL_PIXELFORMAT_RGBA64,
        argb64 = sdl3.SDL_PIXELFORMAT_ARGB64,
        bgra64 = sdl3.SDL_PIXELFORMAT_BGRA64,
        abgr64 = sdl3.SDL_PIXELFORMAT_ABGR64,
        rgb48_float = sdl3.SDL_PIXELFORMAT_RGB48_FLOAT,
        bgr48_float = sdl3.SDL_PIXELFORMAT_BGR48_FLOAT,
        rgba64_float = sdl3.SDL_PIXELFORMAT_RGBA64_FLOAT,
        argb64_float = sdl3.SDL_PIXELFORMAT_ARGB64_FLOAT,
        bgra64_float = sdl3.SDL_PIXELFORMAT_BGRA64_FLOAT,
        abgr64_float = sdl3.SDL_PIXELFORMAT_ABGR64_FLOAT,
        rgb96_float = sdl3.SDL_PIXELFORMAT_RGB96_FLOAT,
        bgr96_float = sdl3.SDL_PIXELFORMAT_BGR96_FLOAT,
        rgba128_float = sdl3.SDL_PIXELFORMAT_RGBA128_FLOAT,
        argb128_float = sdl3.SDL_PIXELFORMAT_ARGB128_FLOAT,
        bgra128_float = sdl3.SDL_PIXELFORMAT_BGRA128_FLOAT,
        abgr128_float = sdl3.SDL_PIXELFORMAT_ABGR128_FLOAT,
        yv12 = sdl3.SDL_PIXELFORMAT_YV12,
        iyuv = sdl3.SDL_PIXELFORMAT_IYUV,
        yuy2 = sdl3.SDL_PIXELFORMAT_YUY2,
        uyvy = sdl3.SDL_PIXELFORMAT_UYVY,
        yvyu = sdl3.SDL_PIXELFORMAT_YVYU,
        nv12 = sdl3.SDL_PIXELFORMAT_NV12,
        nv21 = sdl3.SDL_PIXELFORMAT_NV21,
        p010 = sdl3.SDL_PIXELFORMAT_P010,
        external_oes = sdl3.SDL_PIXELFORMAT_EXTERNAL_OES,
        mjpg = sdl3.SDL_PIXELFORMAT_MJPG,
        // NOTE: remaining are duplicates of more explicit bit layouts above
        // rgba32 = sdl3.SDL_PIXELFORMAT_RGBA32,
        // argb32 = sdl3.SDL_PIXELFORMAT_ARGB32,
        // bgra32 = sdl3.SDL_PIXELFORMAT_BGRA32,
        // abgr32 = sdl3.SDL_PIXELFORMAT_ABGR32,
        // rgbx32 = sdl3.SDL_PIXELFORMAT_RGBX32,
        // xrgb32 = sdl3.SDL_PIXELFORMAT_XRGB32,
        // bgrx32 = sdl3.SDL_PIXELFORMAT_BGRX32,
        // xbgr32 = sdl3.SDL_PIXELFORMAT_XBGR32,
    };

    pub fn init(
        renderer: Renderer,
        format: PixelFormat,
        access: Access,
        w: c_int,
        h: c_int,
    ) error{SDLError}!Texture {
        const f: c_uint = @intCast(@intFromEnum(format));
        const a: c_uint = @intCast(@intFromEnum(access));

        if (sdl3.SDL_CreateTexture(renderer.ptr, f, a, w, h)) |texture| {
            return .{ .ptr = texture };
        } else {
            return error.SDLError;
        }
    }

    pub fn deinit(this: Texture) void {
        sdl3.SDL_DestroyTexture(this.ptr);
    }
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
        const c_title = try Allocator.dupeZ(allocator, u8, title);
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

    pub fn setSize(this: Window, w: u32, h: u32) !void {
        if (!sdl3.SDL_SetWindowSize(this.ptr, @intCast(w), @intCast(h))) {
            return error.SDLError;
        }
    }

    pub fn setTitle(this: Window, title: [:0]const u8) !void {
        if (!sdl3.SDL_SetWindowTitle(this.ptr, title)) {
            return error.SDLError;
        }
    }
};

fn frect(qrect: Quad(f32)) sdl3.SDL_FRect {
    return .{
        .x = qrect.@"0",
        .y = qrect.@"1",
        .w = qrect.@"2",
        .h = qrect.@"3",
    };
}
