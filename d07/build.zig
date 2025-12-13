const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = .Debug;

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("../utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const main_file_path = b.path("src/main.zig");
    const exe = b.addExecutable(.{ .name = "d07", .root_module = b.createModule(.{
        .root_source_file = main_file_path,
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "utils", .module = utils }},
    }), .use_llvm = true });

    const test_step = b.step("test", "Run unit tests");
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = main_file_path,
            .target = target,
            .imports = &.{.{ .name = "utils", .module = utils }},
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    b.installArtifact(exe);
}
