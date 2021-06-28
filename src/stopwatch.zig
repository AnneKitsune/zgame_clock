const std = @import("std");

/// A span of time that is started but might not have an end yet.
pub const TimeSpan = struct {
    /// The instant at which the span started.
    start: u128,
    /// The instant at which the span stopped, if any.
    stop: ?u128 = null,

    pub fn elapsed(self: *const @This()) u64 {
        if (self.stop) |s| {
            return @intCast(u64, s - self.start);
        }
        return 0;
    }
};

/// A stopwatch used to calculate time differences.
pub const Stopwatch = struct {
    /// All the time spans that this stopwatch has been or is still running.
    /// Only the last timespan is allowed to have no stop value, which means it
    /// is still active.
    spans: std.ArrayList(TimeSpan),

    pub fn init(alloc: *std.mem.Allocator) @This() {
        return @This(){
            .spans = std.ArrayList(TimeSpan).init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.spans.deinit();
    }

    /// Starts the stopwatch.
    ///
    /// If it is already started, it will create a new split.
    /// This means it will stop and start the stopwatch, creating a new TimeSpan
    /// in the process.
    pub fn start(self: *@This(), current_time: u128) !?TimeSpan {
        // if no split or last split is stopped, create new one.
        const ret = try self.stop(current_time);
        try self.spans.append(TimeSpan{
            .start = current_time,
            .stop = null,
        });
        return ret;
    }

    /// Stops the stopwatch without resetting it.
    pub fn stop(self: *@This(), current_time: u128) !?TimeSpan {
        var ret: ?TimeSpan = null;
        if (self.is_running() and self.spans.items.len > 0) {
            self.spans.items[self.spans.items.len - 1].stop = current_time;
            ret = self.spans.items[self.spans.items.len - 1];
        }
        return ret;
    }

    /// Returns whether the stopwatch is running.
    pub fn is_running(self: *const @This()) bool {
        // if no spans or last span has an end, we are not running.
        // equiv: if we have splits and the last one has no stop
        return self.spans.items.len > 0 and self.spans.items[self.spans.items.len - 1].stop == null;
    }

    /// Returns the total elapsed time accumulated inside of this stopwatch.
    pub fn elapsed(self: *const @This()) u64 {
        var sum: u64 = 0;
        for (self.spans.items) |span| {
            sum += span.elapsed();
        }
        return sum;
    }
};

const TEST_DELAY = 5;

test "Repeated stops" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();

    var count = @as(u32, 0);
    while (count < 10000) {
        _ = try sw.start(0);
        count += 1;
    }
    _ = try sw.stop(0);
    try std.testing.expectEqual(sw.spans.items.len, 10000);
    try std.testing.expect(sw.spans.items[sw.spans.items.len - 1].stop != null);
}

test "Elapsed none" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    _ = try sw.stop(5);
    _ = try sw.stop(20);
    try std.testing.expectEqual(sw.elapsed(), 0);
}

test "elapsed_ms" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    _ = try sw.start(0);
    _ = try sw.stop(TEST_DELAY);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
}

test "stop" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    _ = try sw.start(0);
    _ = try sw.stop(TEST_DELAY);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
    _ = try sw.stop(TEST_DELAY);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
}

test "resume_once" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    try std.testing.expectEqual(sw.spans.items.len, 0);
    _ = try sw.start(0);
    try std.testing.expectEqual(sw.spans.items.len, 1);
    _ = try sw.stop(TEST_DELAY);
    try std.testing.expectEqual(sw.spans.items.len, 1);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
    _ = try sw.start(TEST_DELAY);
    try std.testing.expectEqual(sw.spans.items.len, 2);
    _ = try sw.stop(TEST_DELAY * 2);
    try std.testing.expectEqual(sw.elapsed(), 2 * TEST_DELAY);
}

test "resume_twice" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    try std.testing.expectEqual(sw.spans.items.len, 0);
    _ = try sw.start(0);
    _ = try sw.stop(TEST_DELAY);
    try std.testing.expectEqual(sw.spans.items.len, 1);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
    _ = try sw.start(TEST_DELAY);
    try std.testing.expectEqual(sw.spans.items.len, 2);
    _ = try sw.start(TEST_DELAY);
    _ = try sw.stop(TEST_DELAY * 2);
    try std.testing.expectEqual(sw.spans.items.len, 3);
    try std.testing.expectEqual(sw.elapsed(), 2 * TEST_DELAY);
    _ = try sw.start(TEST_DELAY * 2);
    try std.testing.expectEqual(sw.spans.items.len, 4);
    _ = try sw.stop(TEST_DELAY * 3);
    try std.testing.expectEqual(sw.elapsed(), 3 * TEST_DELAY);
}

test "is_running" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    try std.testing.expect(!sw.is_running());
    _ = try sw.start(0);
    try std.testing.expect(sw.is_running());
    _ = try sw.stop(0);
    try std.testing.expect(!sw.is_running());
}

test "reset" {
    var sw = Stopwatch.init(std.testing.allocator);
    defer sw.deinit();
    _ = try sw.start(0);
    sw.spans.clearRetainingCapacity();
    try std.testing.expect(!sw.is_running());
    _ = try sw.start(5);
    _ = try sw.stop(TEST_DELAY + 5);
    try std.testing.expectEqual(sw.elapsed(), TEST_DELAY);
}
