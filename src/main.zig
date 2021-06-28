//! Utilities for working with time in games.
//!
//! Original version from the Amethyst Engine under the dual license Apache/MIT.
//!
//! This is a rework of the original `Time` struct. It has been heavily simplified
//! and documentation has been added.

const std = @import("std");

/// Frame timing values.
pub const Time = struct {
    /// Time elapsed since the last frame.
    delta_time: u64 = 0,
    /// Time elapsed since the last frame ignoring the time speed multiplier.
    delta_real_time: u64 = 0,
    /// Rate at which `State::fixed_update` is called.
    fixed_time: u64 = 16_666_666,
    /// The total number of frames that have been played in this session.
    frame_number: u64 = 0,
    ///Time elapsed since game start, ignoring the speed multipler.
    absolute_real_time: u64 = 0,
    ///Time elapsed since game start, taking the speed multiplier into account.
    absolute_time: u64 = 0,
    ///Time multiplier. Affects returned delta_time and absolute_time.
    time_scale: f32 = 1.0,
    /// Fixed timestep accumulator.
    fixed_time_accumulator: u64 = 0,

    /// Sets delta_time to the given `Duration`.
    /// Updates the struct to reflect the changes of this frame.
    /// This should be called before using step_fixed_update.
    pub fn advance_frame(self: *@This(), time_diff: u64) void {
        self.delta_time = @floatToInt(u64, @intToFloat(f64, time_diff) * self.time_scale);
        self.delta_real_time = time_diff;
        self.frame_number += 1;

        self.absolute_time += self.delta_time;
        self.absolute_real_time += self.delta_real_time;
        self.fixed_time_accumulator += self.delta_real_time;
    }

    /// Checks to see if we should perform another fixed update iteration, and if so, returns true
    /// and reduces the accumulator.
    pub fn step_fixed_update(self: *@This()) bool {
        if (self.fixed_time_accumulator >= self.fixed_time) {
            self.fixed_time_accumulator -= self.fixed_time;
            return true;
        }
        return false;
    }
};



fn approx_zero(v: u64) bool {
    //return v >= -0.000001 and v <= 0.000001;
    return v == 0;
}

// Test that fixed_update methods accumulate and return correctly
// Test confirms that with a fixed update of 120fps, we run fixed update twice with the timer
// Runs at 10 times game speed, which shouldn't affect fixed updates
test "Fixed update 120 fps" {
    var time = Time{};
    time.fixed_time = std.time.ns_per_s / 120;
    time.time_scale = 10.0;

    const step = std.time.ns_per_s / 60;
    var fixed_count = @as(u32, 0);
    var iter_count = @as(u32, 0);
    while (iter_count < 60) {
        time.advance_frame(step);
        while (time.step_fixed_update()) {
            fixed_count += 1;
        }
        iter_count += 1;
    }

    try std.testing.expectEqual(fixed_count, 120);
}

// Test that fixed_update methods accumulate and return correctly
// Test confirms that with a fixed update every 1 second, it runs every 1 second only
test "Fixed update 1 sec" {
    var time = Time{};
    time.fixed_time = std.time.ns_per_s;

    const step = std.time.ns_per_s / 60;
    var fixed_count = @as(u32, 0);
    var iter_count = @as(u32, 0);
    while (iter_count < 130) {
        // Run two seconds
        time.advance_frame(step);
        while (time.step_fixed_update()) {
            fixed_count += 1;
        }
        iter_count += 1;
    }
    try std.testing.expectEqual(fixed_count, 2);
}

test "All getters" {
    var time = Time{};

    time.time_scale = 2.0;
    time.fixed_time = std.time.ns_per_s / 120;
    const step = std.time.ns_per_s / 60;
    time.advance_frame(step);
    try std.testing.expectEqual(time.time_scale, 2.0);
    try std.testing.expect(approx_zero(time.delta_time - step * 2));
    try std.testing.expect(approx_zero(time.delta_real_time - step));
    try std.testing.expect(approx_zero(time.absolute_time - step * 2));
    try std.testing.expect(approx_zero(time.absolute_real_time - step));
    try std.testing.expectEqual(time.frame_number, 1);
    try std.testing.expectEqual(time.time_scale, 2.0);
    try std.testing.expectEqual(time.fixed_time, std.time.ns_per_s / 120);

    time.advance_frame(step);
    try std.testing.expectEqual(time.time_scale, 2.0);
    try std.testing.expect(approx_zero(time.delta_time - step * 2));
    try std.testing.expect(approx_zero(time.delta_real_time - step));
    try std.testing.expect(approx_zero(time.absolute_time - step * 4));
    try std.testing.expect(approx_zero(
        time.absolute_real_time - step * 2
    ));
    try std.testing.expectEqual(time.frame_number, 2);
    try std.testing.expectEqual(time.time_scale, 2.0);
    try std.testing.expectEqual(time.fixed_time, std.time.ns_per_s / 120);
}
