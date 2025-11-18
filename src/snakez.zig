const std = @import("std");
const data = @import("data.zig");
const math = std.math;
const Coord = data.Coord;

/// Integer type describing game size.
pub const size_t = u6;
/// Bias added to game size to get field length.
pub const size_bias: usize = 11; // size 0 is 11x11 field

/// Direction of facing and movement.  North is the top of the screen, East is
/// the right, etc.
const Direction = enum {
    North,
    East,
    South,
    West,

    /// Calculate position adjacent to another in this direction.
    pub fn adjacentOf(this: Direction, pos: Coord(u8)) Coord(u8) {
        const offset = this.vector();

        return .{
            .x = @max(0, @as(i9, @intCast(pos.x)) +| offset.x),
            .y = @max(0, @as(i9, @intCast(pos.y)) +| offset.y),
        };
    }

    /// Get the opposite direction.
    pub fn opposite(this: Direction) Direction {
        return switch (this) {
            .North => .South,
            .East => .West,
            .South => .North,
            .West => .East,
        };
    }

    /// Return a cardinal unit vector for this direction.
    pub fn vector(this: Direction) Coord(i8) {
        return switch (this) {
            .North => .{ .x = 0, .y = -1 },
            .East => .{ .x = 1, .y = 0 },
            .South => .{ .x = 0, .y = 1 },
            .West => .{ .x = -1, .y = 0 },
        };
    }
};

/// Field of tiles where game takes place.
const Field = struct {
    tiles: []Tile,
    len: usize,

    /// Pass in tiles slice that will be managed by this field.
    pub fn init(tiles: []Tile) Field {
        if (tiles.len == 0) {
            @panic("empty Field");
        }

        for (tiles) |*tile| {
            tile.* = .empty;
        }

        return .{
            .tiles = tiles,
            .len = math.sqrt(tiles.len),
        };
    }

    /// Return tile at the specified location.
    pub fn tileAt(this: *Field, pos: Coord(u8)) ?*Tile {
        if (pos.x < this.len and pos.y < this.len) {
            return &this.tiles[pos.x + pos.y * this.len];
        } else {
            return null;
        }
    }

    // Return location of the specified tile.
    pub fn locationOf(this: *Field, tile: *Tile) Coord(u8) {
        const start_addr = @intFromPtr(&this.tiles[0]);
        const max_addr = start_addr + @sizeOf(Tile) * (this.tiles.len - 1);
        const tile_addr = @intFromPtr(tile);

        if (tile_addr < start_addr or tile_addr > max_addr) {
            return .{ .x = 255, .y = 255 };
        }

        // TODO: verify behavior with unaligned pointer arg
        const n = @divExact(tile_addr - start_addr, @sizeOf(Tile));
        const y: u8 = @intCast(@divFloor(n, this.len));
        const x: u8 = @intCast(@mod(n, this.len));

        return .{ .x = x, .y = y };
    }
};

/// Player snake.
const Snake = struct {
    /// Location of tile where snake head is found.
    head: *Tile,
    /// Direction the snake is facing.
    dir: Direction,
    /// Living state of the snake.
    state: State,
    /// Actual length of snake.
    len: usize,
    /// Target size of snake.
    sz: usize,

    /// Snake segment iterator.
    pub const Iterator = struct {
        curr: ?*Tile,

        /// Begin iterating from tile.
        pub fn init(head: *Tile) Iterator {
            return .{ .curr = head };
        }

        /// Get the next result.
        pub fn next(this: *Iterator) ?*Tile {
            return if (this.curr) |tile| switch (tile.*) {
                .snake => |next_tile| blk: {
                    this.curr = next_tile;
                    break :blk tile;
                },
                else => blk: {
                    this.curr = null;
                    break :blk null;
                },
            } else null;
        }
    };

    /// Snake living status.
    pub const State = enum {
        alive,
        dead,
    };

    /// Set location of head and direction snake is facing.
    pub fn init(head: *Tile, dir: Direction) Snake {
        return .{
            .head = head,
            .dir = dir,
            .state = .alive,
            .len = 1,
            .sz = 1,
        };
    }

    /// Iterate over snake segments.
    pub fn iterate(this: *Snake) Iterator {
        return Iterator.init(this.head);
    }

    /// Grow the snake into the field tile it is facing.  This will extend the
    /// head of the snake forward and may lead to the snake's death.  If the
    /// snake enters a tile with food, it will eat the food.
    pub fn grow(this: *Snake, field: *Field) void {
        const old_pos = field.locationOf(this.head);
        const new_pos = this.dir.adjacentOf(old_pos);

        if (field.tileAt(new_pos)) |tile| switch (tile.*) {
            .empty => {
                tile.* = .{ .snake = this.head }; // point tile at old head
                this.head = tile; // snake head now in new tile
                this.len += 1; // snake now longer
            },
            .food => |value| this.sz += value,
            .blocked, .snake => this.kill(),
        } else unreachable;
    }

    /// Set snake living status to dead.
    pub fn kill(this: *Snake) void {
        this.state = .dead;
    }

    /// Remove final tail segment of the snake.
    pub fn shrink(this: *Snake) void {
        var tail = this.head;
        var it = this.iterate();

        while (it.next()) |tile| {
            tail = tile;
        }

        if (tail != this.head) {
            tail.* = .empty;
        }
    }

    /// Turn the snake in the specified direction.
    pub fn turn(this: *Snake, dir: Direction) void {
        // TODO: figure out how to not go backwards
        this.dir = dir;
    }
};

/// Snakez game state.
pub const Snakez = struct {
    /// Caller-provided buffer where game state is kept.
    buffer: []u8,
    /// Game field where play takes place.
    field: Field,
    /// Player snake.
    snake: Snake,
    /// Value of next food pellet.
    food_value: u8,
    /// Length of field.
    len: usize,

    /// Calculate the size of the buffer needed for a game size.
    pub fn bufferSize(game_size: size_t) usize {
        return Snakez.tileCount(game_size) * @sizeOf(Tile);
    }

    /// Calculate the number of tiles for a game size.
    pub fn tileCount(game_size: size_t) usize {
        const len: usize = game_size + size_bias;
        return len * len;
    }

    /// Initialize with a buffer at least Snakez.bufferSize() bytes in length.
    pub fn init(game_size: size_t, buffer: []u8) Snakez {
        if (buffer.len < Snakez.bufferSize(game_size)) {
            @panic("buffer for Snakez game too small");
        }

        const len = game_size + size_bias;
        const num_tiles = Snakez.tileCount(game_size);
        const tiles: [*]Tile = @ptrCast(@alignCast(&buffer[0]));
        var field = Field.init(tiles[0..num_tiles]);

        const snake = if (field.tileAt(.{ .x = 4, .y = 4 })) |tile| blk: {
            tile.* = .{ .snake = null };
            break :blk Snake.init(tile, .East);
        } else unreachable;

        for (0..len) |n| {
            field.tileAt(.{ .x = 0, .y = @intCast(n) }).?.* = .blocked;
            field.tileAt(.{ .x = @intCast(n), .y = 0 }).?.* = .blocked;
            field.tileAt(.{ .x = @intCast(len - 1), .y = @intCast(n) }).?.* = .blocked;
            field.tileAt(.{ .x = @intCast(n), .y = @intCast(len - 1) }).?.* = .blocked;
        }

        return .{
            .buffer = buffer,
            .field = field,
            .snake = snake,
            .food_value = 1,
            .len = game_size + size_bias,
        };
    }

    /// Move the game forward one tick.
    pub fn tick(this: *Snakez) void {
        if (this.snake.state == .alive) {
            if (this.snake.len >= this.snake.sz) {
                this.snake.shrink();
            }

            this.snake.grow(&this.field);
        }
    }
};

/// Tile state.
const Tile = union(enum) {
    /// Tile is empty.
    empty: void,
    /// Tile is blocked.
    blocked: void,
    /// Tile contains part of a snake which trails into another tile.
    snake: ?*Tile,
    /// Tile contains food.
    food: u8,
};
