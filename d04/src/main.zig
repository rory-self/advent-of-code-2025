const std = @import("std");

// Constants //
const TEST_INPUT_FILEPATH = "test.txt";
const IO_BUF_SIZE: usize = 1024;
const ACCESSIBILITY_THRESHOLD: u3 = 4;
const DIRECTIONS: [8][2]i2 = .{
    .{ -1, -1 },
    .{ -1, 0 },
    .{ -1, 1 },
    .{ 0, -1 },
    .{ 0, 1 },
    .{ 1, -1 },
    .{ 1, 0 },
    .{ 1, 1 },
};

// Types and Aliases //
const Space = enum {
    empty,
    roll,

    fn fromChar(char: u8) !Space {
        return switch (char) {
            '@' => .roll,
            '.' => .empty,
            else => error.InvalidCharacter,
        };
    }
};
const SpaceGrid = [][]Space;
const Allocator = std.mem.Allocator;

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArg;

    const clearance_return = try calcClearableRolls(input_filepath, allocator);
    const initial_accessible_rolls, const rolls_removed = clearance_return;

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Initially accessible rolls: {d}\n", .{initial_accessible_rolls});
    try stdout_writer.print("Total rolls removed: {d}\n", .{rolls_removed});
    try stdout_writer.flush();
}

fn calcClearableRolls(input_filepath: []const u8, allocator: Allocator) !struct { u16, u16 } {
    var grid = try readGridFromFile(input_filepath, allocator);
    if (grid.len == 0) {
        return error.EmptyGrid;
    }

    const initial_rolls_removed = try clearRolls(&grid, allocator);
    var total_rolls_removed = initial_rolls_removed;
    while (clearRolls(&grid, allocator)) |rolls_removed| {
        total_rolls_removed += rolls_removed;

        if (rolls_removed == 0) {
            return .{ initial_rolls_removed, total_rolls_removed };
        }
    } else |err| {
        return err;
    }

    unreachable;
}

fn readGridFromFile(filepath: []const u8, allocator: Allocator) !SpaceGrid {
    var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer input_file.close();

    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var file_reader = input_file.reader(&reader_buf);
    var reader = &file_reader.interface;

    var space_grid: std.ArrayList([]Space) = .empty;
    while (reader.takeDelimiterExclusive('\n')) |line| {
        reader.toss(1);

        var spaces = try allocator.alloc(Space, line.len);
        for (line, 0..) |space_char, i| {
            spaces[i] = try Space.fromChar(space_char);
        }

        try space_grid.append(allocator, spaces);
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
    }

    return try space_grid.toOwnedSlice(allocator);
}

fn clearRolls(grid: *SpaceGrid, allocator: Allocator) !u16 {
    var accessible_rolls: std.ArrayList(*Space) = .empty;
    for (grid.*, 0..) |row, i| {
        for (row, 0..) |space, j| {
            if (space != .roll) {
                continue;
            }

            if (isRollAccessible(i, j, grid.*, row.len)) {
                try accessible_rolls.append(allocator, &grid.*[i][j]);
            }
        }
    }

    var rolls_removed: u16 = 0;
    for (accessible_rolls.items) |roll_space| {
        roll_space.* = .empty;
        rolls_removed += 1;
    }

    return rolls_removed;
}

fn isRollAccessible(
    row: usize,
    col: usize,
    grid: []const []const Space,
    num_col: usize,
) bool {
    var num_rolls: u8 = 0;
    for (DIRECTIONS, 0..) |direction, i| {
        if (DIRECTIONS.len - i < ACCESSIBILITY_THRESHOLD - num_rolls) {
            break;
        }

        const new_row, const row_overflow = addWithOverflow(row, direction[0]);
        const new_col, const col_overflow = addWithOverflow(col, direction[1]);
        if (row_overflow or col_overflow or new_row >= grid.len or new_col >= num_col) {
            continue;
        }

        if (grid[new_row][new_col] == .roll) {
            num_rolls += 1;
            if (num_rolls == ACCESSIBILITY_THRESHOLD) {
                return false;
            }
        }
    }

    return true;
}

fn addWithOverflow(a: usize, b: i2) struct { usize, bool } {
    if (b == 0) {
        return .{ a, false };
    }

    const padded_b = @as(i64, b);
    const unsigned_b: usize = @abs(padded_b);
    const new_val, const overflow = if (b > 0) @addWithOverflow(a, unsigned_b) else @subWithOverflow(a, unsigned_b);

    return .{ new_val, overflow == 0b1 };
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const test_result = try calcClearableRolls(TEST_INPUT_FILEPATH, allocator);
    const initially_accessible_rolls, const removed_rolls = test_result;
    try std.testing.expect(initially_accessible_rolls == 13);
    try std.testing.expect(removed_rolls == 43);
}
