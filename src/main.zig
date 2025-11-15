const std = @import("std");
const sdl = @import("sdl.zig");
const Snakez = @import("snakez.zig").Snakez;

const title = "Snakez";
const name = "snakez";
const ident = "page.remer." ++ name;
const version = "0.0";
const size = 63;
const scale = 10;

pub fn main() void {
    var game: Snakez(size) = Snakez(size).init();
    var status: u8 = 0;

    run(&game) catch |err| switch (err) {
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

fn run(game: *Snakez(size)) error{ OutOfMemory, SDLError }!void {
    const winsz: u32 = @intCast(game.fieldSize() * scale);
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

    try window.setSize(winsz, winsz);

    // https://stackoverflow.com/questions/50361975/sdl-framerate-cap-implementation

    while (!done) {
        while (sdl.pollEvent()) |event| {
            switch (event.type) {
                sdl.sdl3.SDL_EVENT_WINDOW_EXPOSED => {
                    try render(renderer, game);
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

fn render(renderer: sdl.Renderer, game: *Snakez(size)) !void {
    const winsz = renderer.getOutputSize();
    const dim: u8 = @as(u8, @intCast(size)) + 2;
    const texture = try sdl.Texture.init(renderer, .rgb332, .target, dim, dim);
    defer texture.deinit();

    // clear window
    try renderer.setDrawColor(0, 0, 0, 255);
    try renderer.clear();

    // draw off-screen texture of game map
    try renderer.setTarget(texture);
    try renderer.setDrawColor(0, 0, 0, 255);
    try renderer.clear();
    try renderer.setDrawColor(0, 255, 0, 255);

    const field_size = game.fieldSize();
    for (0..field_size) |x| for (0..field_size) |y| {
        const state = game.stateAt(.{ .x = @intCast(x), .y = @intCast(y) });

        switch (state) {
            .blocked, .snake => try renderer.setDrawColor(0, 255, 0, 255),
            .food => try renderer.setDrawColor(255, 0, 0, 255),
            else => {},
        }

        switch (state) {
            .empty => {},
            else => try renderer.point(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) }),
        }
    };

    // copy off-screen texture to window
    try renderer.setTargetDefault();
    try renderer.renderTexture(
        texture,
        .{ .x = 0, .y = 0, .w = dim, .h = dim },
        .{ .x = 0, .y = 0, .w = @floatFromInt(winsz.w), .h = @floatFromInt(winsz.h) },
    );

    // sync render buffer to screen
    try renderer.present();
}
