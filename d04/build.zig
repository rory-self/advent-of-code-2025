const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = .Debug;
    const exe = b.addExecutable(.{ .name = "d04", .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }), .use_llvm = true });

    b.installArtifact(exe);
}
