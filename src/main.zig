const std = @import("std");
const sdl = @import("sdl.zig");

const title = "Snakez";
const name = "snakez";
const ident = "page.remer." ++ name;
const version = "0.0";
const size = 64;
const scale = 10;

pub fn main() void {
    var status: u8 = 0;

    run() catch |err| switch (err) {
        error.SDLError => {
            std.log.err("Error: SDLError: {s}", .{sdl.getError()});
            status = 1;
        },
        else => {
            std.log.err("Error: {s}", .{@errorName(err)});
            status = 1;
        },
    };

    std.process.exit(status);
}

fn run() error{ OutOfMemory, SDLError }!void {
    var done = false;

    defer sdl.quit();
    sdl.setMainReady();

    try sdl.setAppMetadata(name, version, ident);
    try sdl.init(.{ .video = true, .gamepad = true });

    const window = try sdl.Window.init(
        std.heap.smp_allocator,
        title,
        300,
        200,
        .{ .resizable = true },
    );
    defer window.deinit();

    const renderer = try sdl.Renderer.init(window);
    defer renderer.deinit();

    try window.setSize(size * scale, size * scale);

    while (!done) {
        while (sdl.pollEvent()) |event| {
            switch (event.type) {
                sdl.sdl3.SDL_EVENT_WINDOW_EXPOSED => {
                    try renderer.setDrawColor(0, 0, 0, 255);
                    try renderer.clear();
                    try renderer.present();
                },
                sdl.sdl3.SDL_EVENT_KEY_DOWN => {
                    _ = switch (event.key.key) {
                        sdl.sdl3.SDLK_DOWN => try window.setTitle("down"),
                        sdl.sdl3.SDLK_LEFT => try window.setTitle("left"),
                        sdl.sdl3.SDLK_RIGHT => try window.setTitle("right"),
                        sdl.sdl3.SDLK_UP => try window.setTitle("up"),
                        else => false,
                    };
                },
                sdl.sdl3.SDL_EVENT_QUIT => done = true,
                else => {},
            }
        }
    }
}
