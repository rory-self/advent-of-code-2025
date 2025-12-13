const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = .Debug;

    const utils_module = b.addModule("utils", .{
        .root_source_file = b.path("../utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "utils", .module = utils_module }},
    });
    const exe = b.addExecutable(.{
        .name = "d07",
        .root_module = main_module,
        .use_llvm = true,
    });

    const test_step = b.step("test", "Run unit tests");
    const tests = b.addTest(.{ .root_module = main_module });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    b.installArtifact(exe);
}
