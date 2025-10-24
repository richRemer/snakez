const std = @import("std");
const sdl = @import("sdl.zig");

const title = "Snakez";
const name = "snakez";
const ident = "page.remer." ++ name;
const version = "0.0";

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
    try sdl.init(.{ .video = true });

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

    while (!done) {
        while (sdl.pollEvent()) |event| {
            if (event.type == sdl.sdl3.SDL_EVENT_QUIT) {
                done = true;
            }
        }
    }
}
