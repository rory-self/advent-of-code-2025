const std = @import("std");

const TEST_INPUT_FILEPATH = "test.txt";
const IO_BUF_SIZE: usize = 1024;
const MAX_ROLLS: u3 = 4;
const DIRECTIONS: [8][2]i2 = .{
    .{-1, -1},
    .{-1, 0},
    .{-1, 1},
    .{0, -1},
    .{0, 1},
    .{1, -1},
    .{1, 0},
    .{1, 1},
};

const Space = enum {
    empty,
    roll,

    fn fromChar(char: u8) !Space {
        return switch (char) {
            '@'  => .roll,
            '.'  => .empty,
            else => error.InvalidCharacter,
        };
    }
};
const SpaceGrid = []const []const Space;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArg;

    const accessible_rolls: u16 = try calcAccessibleRolls(input_filepath, allocator);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Accessible Rolls: {d}\n", .{accessible_rolls});
    try stdout_writer.flush();
}

fn calcAccessibleRolls(input_filepath: []const u8, allocator: Allocator) !u16 {
    const grid = try readGridFromFile(input_filepath, allocator);
    if (grid.len == 0) {
        return error.EmptyGrid;
    }
    const row_len = grid[0].len;

    var accessible_rolls: u16 = 0;
    for (0..grid.len) |row| {
        for (0..row_len) |col| {
            if (grid[row][col] != .roll) continue;

            if (isRollAccessible(row, col, grid, grid.len, row_len)) {
                accessible_rolls += 1;
            }
        }
    }

    return accessible_rolls;
}

fn readGridFromFile(filepath: []const u8, allocator: Allocator) !SpaceGrid {
    var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer input_file.close();

    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var file_reader = input_file.reader(&reader_buf);
    var reader = &file_reader.interface;

    var space_grid: std.ArrayList([]Space) = .empty;
    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        reader.toss(1);

        var spaces = try allocator.alloc(Space, line.len);
        for (0..line.len) |i| {
            spaces[i] = try Space.fromChar(line[i]);
        }

        try space_grid.append(allocator, spaces);
    }
    
    return try space_grid.toOwnedSlice(allocator);
}

fn isRollAccessible(
    row: usize,
    col: usize,
    grid: SpaceGrid,
    num_rows: usize,
    num_col: usize,
) bool { 
    var num_rolls: u8 = 0;
    for (DIRECTIONS, 0..) |direction, i| {
        if (DIRECTIONS.len - i < MAX_ROLLS - num_rolls) {
            break;
        }

        const new_row, const row_overflow = addWithOverflow(row, direction[0]);
        const new_col, const col_overflow = addWithOverflow(col, direction[1]);
        if (row_overflow or col_overflow or new_row >= num_rows or new_col >= num_col) continue;

        if (grid[new_row][new_col] == .roll) {
            num_rolls += 1;
            if (num_rolls == MAX_ROLLS) return false;
        }
    }

    return true;
}

fn addWithOverflow(a: usize, b: i2) struct { usize, bool } {
    if (b == 0) return .{ a, false };

    const padded_b = @as(i64, b);
    const unsigned_b: usize = @abs(padded_b);
    const new_val, const overflow = if (b > 0) @addWithOverflow(a, unsigned_b)
        else @subWithOverflow(a, unsigned_b);

    return .{ new_val, overflow == 0b1 };
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const accessible_rolls = try calcAccessibleRolls(TEST_INPUT_FILEPATH, allocator);
    try std.testing.expect(accessible_rolls == 13);
}

