const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zgame_clock", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var t1 = b.addTest("src/time.zig");
    t1.setBuildMode(mode);
    var t2 = b.addTest("src/stopwatch.zig");
    t2.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&t1.step);
    test_step.dependOn(&t2.step);
}
