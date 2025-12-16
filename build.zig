const std = @import("std");

const NUM_DAYS = 8;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = .Debug;

    const utils_module = b.addModule("utils", .{
        .root_source_file = b.path("utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    for (1..NUM_DAYS + 1) |i| {
        const day_string = b.fmt("d0{d}", .{ i });
        const test_step_string = b.fmt("test{d}", .{ i });
        const main_file_rel_path = b.fmt("src/{s}/main.zig", .{ day_string });

        const main_module = b.createModule(.{
            .root_source_file = b.path(main_file_rel_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "utils", .module = utils_module }},
        });
        const exe = b.addExecutable(.{
            .name = day_string,
            .root_module = main_module,
            .use_llvm = true,
        });

        const test_step = b.step(test_step_string, "Run unit tests");
        const tests = b.addTest(.{ .root_module = main_module });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);

        b.installArtifact(exe);
    }
}
