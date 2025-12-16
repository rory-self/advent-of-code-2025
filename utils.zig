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

pub fn UnsignedToSigned(comptime T: type) type {
    comptime {
        const type_info = @typeInfo(T);
        if (type_info != .int) {
            @compileError(ERR_EXPECTED_INT);
        }

        if (type_info.int.signedness != .unsigned) {
            @compileError("Expeceted an unsigned integer type");
        }

        return @Type(.{
            .int = .{
                .signedness = .signed,
                .bits = type_info.int.bits,
            },
        });
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

        return @Type(.{ .int = .{
            .signedness = type_info.int.signedness,
            .bits = type_info.int.bits + bits_to_extend,
        } });
    }
}
