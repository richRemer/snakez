const sdl = @import("sdl.zig");

/// Return the number of ticks as reported by SDL in nanoseconds.
pub fn now() u64 {
    return sdl.getTicksNS();
}

/// Use the SDL library as a clock to establish a rate.
pub const RateLimiter = struct {
    t0: u64,
    tick: u64,
    rate: u16,

    /// Set the rate in number of cycles per second.
    pub fn init(rate: u16) RateLimiter {
        return .{ .t0 = 0, .tick = 0, .rate = rate };
    }

    /// Returns true the first time this method is called for each tick.
    /// Caller should execute rate limited behavior then wait for this method
    /// to return true before executing the behavior again.
    pub fn elapsed(this: *RateLimiter) bool {
        const frame_dur: u64 = 1_000_000_000 / @as(u64, @intCast(this.rate));

        if (this.t0 == 0) {
            return false;
        } else if (now() - this.tick >= frame_dur) {
            this.tick += frame_dur;
            return true;
        } else {
            return false;
        }
    }

    /// Initialize the rate limiter and begin counting from now.
    pub fn start(this: *RateLimiter) void {
        this.t0 = now();
        this.tick = this.t0;
    }
};
