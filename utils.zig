const std = @import("std");

const IO_BUF_SIZE = 128;
const ERR_EXPECTED_INT = "Expected an integer type";
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
    defer args.deinit();
    _ = args.skip();

    const filepath_arg = args.next() orelse return error.MissingArgument;
    return try allocator.dupe(u8, filepath_arg);
}

/// Return the contents of the file as a u8 slice. Must be freed using the allocator.
pub fn readAllFromFile(filepath: []const u8, allocator: Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const file_length = try file.getEndPos();
    const file_contents = try allocator.alloc(u8, file_length);
    errdefer allocator.free(file_contents);

    _ = try file.readAll(file_contents);

    return file_contents;
}

pub fn UnsignedToSigned(comptime T: type) type {
    comptime {
        const type_info = @typeInfo(T);
        if (type_info != .int) {
            @compileError(ERR_EXPECTED_INT);
        }

        if (type_info.int.signedness != .unsigned) {
            @compileError("Expected an unsigned integer type");
        }

        return std.meta.Int(.signed, type_info.int.bits);
    }
}

pub fn UpgradeBitWidth(comptime T: type, comptime bits_to_extend: u16) type {
    comptime {
        if (bits_to_extend == 0) {
            @compileError("Cannot extend by zero bits.");
        }

        const type_info = @typeInfo(T);
        if (type_info != .int) {
            @compileError(ERR_EXPECTED_INT);
        }

        const int_info = type_info.int;
        return std.meta.Int(int_info.signedness, int_info.bits + bits_to_extend);
    }
}
