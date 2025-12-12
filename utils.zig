const std = @import("std");

const IO_BUF_SIZE: usize = 128;
const Allocator = std.mem.Allocator;

pub fn printToStdout(comptime fmt: []const u8, args: anytype) !void {
    const stdout_file = std.fs.File.stdout();
    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_writer = stdout_file.writer(&writer_buf);
    const stdout_interface = &stdout_writer.interface;

    try stdout_interface.print(fmt, args);
    try stdout_interface.flush();
}

pub fn getFilepathArg(allocator: Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();

    return args.next() orelse error.MissingArgument;
}

pub fn readAllFromFile(filepath: []const u8, allocator: Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const file_length = try file.getEndPos();
    const file_contents = try allocator.alloc(u8, file_length);
    _ = try file.readAll(file_contents);

    return file_contents;
}
