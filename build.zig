const std = @import("std");
const builtin = @import("builtin");

const NUM_DAYS = 10;
const TARGET_VERSION = "0.15.2";
const OPTIMISATION_MODE = .Debug;

const UTILS_MODULE_NAME = "utils";
const UTILS_MODULE_PATH = "src/utils.zig";
const MAIN_REL_PATH_FMT = "src/{s}/main.zig";

const DayNum = u4;

pub fn build(b: *std.Build) !void {
    const project_zig_version: std.SemanticVersion = try .parse(TARGET_VERSION);
    if (versionsDoNotMatch(builtin.zig_version, project_zig_version)) {
        return error.ZigVersionMismatch;
    }

    const target = b.standardTargetOptions(.{});
    const utils_module = b.addModule(UTILS_MODULE_NAME, .{
        .root_source_file = b.path(UTILS_MODULE_PATH),
        .target = target,
        .optimize = OPTIMISATION_MODE,
    });

    for (1..NUM_DAYS + 1) |i| {
        const day_num: DayNum = @truncate(i);
        buildDayExe(b, utils_module, day_num, target);
    }
}

fn versionsDoNotMatch(v1: std.SemanticVersion, v2: std.SemanticVersion) bool {
    return v1.major != v2.major or v1.minor != v2.minor or v1.patch != v2.patch;
}

fn buildDayExe(
    b: *std.Build,
    utils_module: *std.Build.Module,
    day_num: DayNum,
    target: std.Build.ResolvedTarget,
) void {
    const day_string = b.fmt("d{d:0>2}", .{day_num});
    const main_file_rel_path = b.fmt(MAIN_REL_PATH_FMT, .{day_string});

    const main_module = b.createModule(.{
        .root_source_file = b.path(main_file_rel_path),
        .target = target,
        .optimize = OPTIMISATION_MODE,
        .imports = &.{.{ .name = UTILS_MODULE_NAME, .module = utils_module }},
    });
    const exe = b.addExecutable(.{
        .name = day_string,
        .root_module = main_module,
        .use_llvm = true,
    });

    const test_step_string = b.fmt("test{d}", .{day_num});
    const test_step = b.step(test_step_string, "Run unit tests");
    const tests = b.addTest(.{ .root_module = main_module });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    b.installArtifact(exe);
}
