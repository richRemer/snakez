const std = @import("std");
const sdl = @import("sdl.zig");
const Snakez = @import("snakez.zig").Snakez;
const RateLimiter = @import("timing.zig").RateLimiter;

const title = "Snakez";
const name = "snakez";
const ident = "page.remer." ++ name;
const version = "0.0";
const size = 63;
const scale = 10;

pub fn main() !void {
    const len = Snakez.bufferSize(size);
    const buffer = try std.heap.smp_allocator.alloc(u8, len);

    var game = Snakez.init(size, buffer);
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

fn run(game: *Snakez) error{ OutOfMemory, SDLError }!void {
    const winsz: u32 = @intCast(game.len * scale);
    var done = false;
    var rate = RateLimiter.init(4);

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

    rate.start();

    while (!done) {
        if (rate.elapsed()) {
            game.tick();
            try render(renderer, game);
        }

        while (sdl.pollEvent()) |event| {
            switch (event.type) {
                sdl.sdl3.SDL_EVENT_WINDOW_EXPOSED => {
                    try render(renderer, game);
                },
                sdl.sdl3.SDL_EVENT_KEY_DOWN => {
                    _ = switch (event.key.key) {
                        sdl.sdl3.SDLK_DOWN => game.snake.turn(.South),
                        sdl.sdl3.SDLK_LEFT => game.snake.turn(.West),
                        sdl.sdl3.SDLK_RIGHT => game.snake.turn(.East),
                        sdl.sdl3.SDLK_UP => game.snake.turn(.North),
                        else => false,
                    };
                },
                sdl.sdl3.SDL_EVENT_QUIT => done = true,
                else => {},
            }
        }
    }
}

fn render(renderer: sdl.Renderer, game: *Snakez) !void {
    const outsz = renderer.getOutputSize();
    const dim: u8 = @intCast(game.len);
    const texture = try sdl.Texture.init(renderer, .rgb332, .target, dim, dim);
    defer texture.deinit();

    // clear window
    try renderer.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 255 });
    try renderer.clear();

    // draw off-screen texture of game map
    try renderer.setTarget(texture);
    try renderer.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 255 });
    try renderer.clear();
    try renderer.setDrawColor(.{ .r = 0, .g = 255, .b = 0, .a = 255 });

    for (0..game.len) |x| for (0..game.len) |y| {
        const state = game.field.tileAt(.{ .x = @intCast(x), .y = @intCast(y) }).?;

        switch (state.*) {
            .blocked, .snake => try renderer.setDrawColor(.{ .r = 0, .g = 255, .b = 0, .a = 255 }),
            .food => try renderer.setDrawColor(.{ .r = 255, .g = 0, .b = 0, .a = 255 }),
            else => {},
        }

        switch (state.*) {
            .empty => {},
            else => try renderer.point(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) }),
        }
    };

    // copy off-screen texture to window
    try renderer.setTargetDefault();
    try renderer.renderTexture(
        texture,
        .{ .x = 0, .y = 0, .w = @floatFromInt(dim), .h = @floatFromInt(dim) },
        .{ .x = 0, .y = 0, .w = @floatFromInt(outsz.w), .h = @floatFromInt(outsz.h) },
    );

    // sync render buffer to screen
    try renderer.present();
}
