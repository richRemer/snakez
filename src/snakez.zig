const std = @import("std");
const data = @import("data.zig");
const Pair = data.Pair;

pub const size_t = u6;
pub const size_bias: usize = 11; // size 0 is 11x11 field
pub const min_field_size: usize = size_bias;
pub const max_field_size: usize = size_bias + std.math.maxInt(size_t);

pub fn Snakez(comptime size: size_t) type {
    const sz = size + size_bias;
    const bufsz = sz * sz * @sizeOf(Snake.Segment);

    return struct {
        // TODO: force alignment more explicitly; for now, rely on Snakez
        // TODO: alignment to be acceptable and place buffer at start
        buffer: [bufsz]u8,
        field: [sz][sz]FieldState,
        snake: Snake,
        food_value: u8,

        pub const FieldState = enum(u2) {
            empty = 0,
            blocked = 1,
            snake = 2,
            food = 3,
        };

        pub fn init() @This() {
            var snakez: @This() = undefined;

            snakez.food_value = 1;
            snakez.snake = Snake.init(&snakez.buffer);

            // initialize empty field with border walls
            for (0..sz) |y| for (0..sz) |x| {
                const edge = x == 0 or x == sz - size_bias + 1 or y == 0 or y == sz - size_bias + 1;
                const state: FieldState = if (edge) .blocked else .empty;
                snakez.stateSet(.{ @intCast(x), @intCast(y) }, state);
            };

            snakez.stateSet(snakez.snake.pos, .snake);

            return snakez;
        }

        pub fn fieldSize(this: *@This()) usize {
            _ = this;
            return sz;
        }

        pub fn stateAt(this: *@This(), pos: Pair(u8)) FieldState {
            if (pos.@"0" < sz and pos.@"1" < sz) {
                return this.field[pos.@"1"][pos.@"0"];
            } else {
                return .empty;
            }
        }

        fn stateSet(this: *@This(), pos: Pair(u8), state: FieldState) void {
            if (pos.@"0" < sz and pos.@"1" < sz) {
                this.field[pos.@"1"][pos.@"0"] = state;
            } else {
                // ignore degenerate case
            }
        }

        fn tick(this: *@This()) void {
            if (this.snake.slither()) |clear_pos| {
                this.stateSet(clear_pos, .empty);
            }

            switch (this.stateAt(this.snake.pos)) {
                .empty => {},
                .blocked, .snake => this.snake.kill(),
                .food => {},
            }
        }
    };
}

pub const Snake = struct {
    buffer: []u8,
    head: *Segment,
    len: usize,
    pos: Pair(u8),
    state: State,

    pub const Segment = struct {
        next: ?*Segment,
        dir: Direction,

        pub const Iterator = struct {
            current: ?*Segment,

            pub fn init(start: ?*Segment) Iterator {
                return .{ .current = start };
            }

            pub fn next(this: *Iterator) ?*Segment {
                if (this.current) |segment| {
                    this.current = segment.next;
                    return segment;
                } else {
                    return null;
                }
            }
        };
    };

    pub const State = enum(u1) {
        alive = 0,
        dead = 1,
    };

    pub fn init(buffer: []u8) Snake {
        return .{
            .buffer = buffer,
            .head = @ptrCast(@alignCast(buffer.ptr)),
            .len = if (buffer.len >= @sizeOf(Segment)) 1 else 0,
            .pos = .{ 4, 4 },
            .state = .alive,
        };
    }

    pub fn capacity(this: Snake) usize {
        return this.buffer.len / @sizeOf(Segment);
    }

    pub fn iterate(this: Snake) Segment.Iterator {
        return Segment.Iterator.init(this.head);
    }

    pub fn kill(this: *Snake) void {
        this.state = .dead;
    }

    pub fn slither(this: *Snake) ?Pair(u8) {
        var pos = this.pos; // position of current segment
        var found = 0; // number of segments found
        var lead_dir: Direction = this.head.dir; // direction to follow leader
        var it = this.iterate();

        // TODO: check if new position ran into obstacle
        while (it.next()) |segment| {
            const dir = segment.dir;

            if (segment == this.head) {
                this.pos = adjacent(pos, dir);
            } else {
                pos = adjacent(pos, dir.opposite());
                segment.dir = lead_dir; // follow the leader
            }

            lead_dir = dir;
            found += 1;
        }

        if (found < this.len) {
            const ptr: [*]Segment = @ptrCast(this.buffer.ptr);
            const len = found + 1;
            const slice = ptr[0..len];

            // TODO: verify offsets in range etc.
            slice[len - 1] = .{ .next = null, .dir = lead_dir };
            slice[len - 2].next = &slice[len - 1];
        }
    }

    pub fn turn(this: *Snake, dir: Direction) void {
        // ignore turn which directs back into previous segment
        if (this.head.next) |next| {
            if (next.dir == dir.opposite()) {
                return;
            }
        }

        this.head.dir = dir;
    }
};

pub const Direction = enum {
    North,
    East,
    South,
    West,

    pub fn opposite(this: Direction) Direction {
        return switch (this) {
            .North => .South,
            .East => .West,
            .South => .North,
            .West => .East,
        };
    }

    pub fn vector(this: Direction) Pair(i2) {
        return switch (this) {
            .North => .{ 0, -1 },
            .East => .{ 1, 0 },
            .South => .{ 0, 1 },
            .West => .{ -1, 0 },
        };
    }
};

fn adjacent(pos: Pair(u8), dir: Direction) Pair(u8) {
    const vector = dir.vector();

    return .{
        pos.@"0" +| vector.@"0",
        pos.@"1" +| vector.@"1",
    };
}
