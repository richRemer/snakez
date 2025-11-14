const sdl = @import("./sdl.zig");

pub fn Point(T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

pub fn Rect(T: type) type {
    const SDLType: type = switch (@typeInfo(T)) {
        .int => sdl.sdl3.SDL_Rect,
        .float => sdl.sdl3.SDL_FRect,
        else => @compileError("invalid Rect type"),
    };

    return struct {
        x: T,
        y: T,
        w: T,
        h: T,

        pub fn toSDL(this: @This()) SDLType {
            return switch (SDLType) {
                sdl.sdl3.SDL_Rect => sdl.sdl3.SDL_Rect{
                    .x = @intCast(this.x),
                    .y = @intCast(this.y),
                    .w = @intCast(this.w),
                    .h = @intCast(this.h),
                },
                sdl.sdl3.SDL_FRect => sdl.sdl3.SDL_FRect{
                    .x = @floatCast(this.x),
                    .y = @floatCast(this.y),
                    .w = @floatCast(this.w),
                    .h = @floatCast(this.h),
                },
                else => unreachable,
            };
        }
    };
}

pub fn Size(T: type) type {
    return struct {
        w: T,
        h: T,
    };
}
