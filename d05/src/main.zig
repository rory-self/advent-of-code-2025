const std = @import("std");
const range_tree = @import("range_tree.zig");

const TEST_INPUT_FILEPATH = "test.txt";
const IO_BUF_SIZE: usize = 1024;

const Allocator = std.mem.Allocator;
const RangeTree = range_tree.RangeTree;
const FreshIdRange = range_tree.FreshIdRange;

const InventoryData = struct {
    fresh_id_ranges: RangeTree,
    available_ids: []const u64,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArg;

    const num_fresh_ids, const possible_fresh_ids = try countFreshIngredientIDs(input_filepath, allocator);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Number of available fresh IDs: {d}\n", .{num_fresh_ids});
    try stdout_writer.print("Total fresh IDs: {d}\n", .{possible_fresh_ids});
    try stdout_writer.flush();
}

fn countFreshIngredientIDs(input_filepath: []const u8, allocator: Allocator) !struct { u16, u64 } {
    const inventory_data = try readInventoryFromFile(input_filepath, allocator);
    const fresh_id_ranges = inventory_data.fresh_id_ranges;

    var num_fresh: u16 = 0;
    for (inventory_data.available_ids) |id| {
        if (fresh_id_ranges.idInRange(id)) {
            num_fresh += 1;
        }
    }

    const possible_fresh_ids = fresh_id_ranges.countIDs();
    return .{ num_fresh, possible_fresh_ids };
}

fn readInventoryFromFile(filepath: []const u8, allocator: Allocator) !InventoryData {
    var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer input_file.close();

    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var file_reader = input_file.reader(&reader_buf);
    var reader = &file_reader.interface;

    // Read fresh ID ranges
    var id_range_tree: RangeTree = .empty;
    while (reader.takeDelimiterExclusive('\n')) |range_str| {
        reader.toss(1);
        if (range_str.len == 0) {
            break;
        }

        const range = try FreshIdRange.fromString(range_str);
        try id_range_tree.insertRange(range, allocator);
    } else |err| {
        return err;
    }

    // Read available IDs
    var available_id_list: std.ArrayList(u64) = .empty;
    while (reader.takeDelimiterExclusive('\n')) |id_str| { 
        reader.toss(1);

        const id = try std.fmt.parseInt(u64, id_str, 10);
        try available_id_list.append(allocator, id);
    } else |err| {
        if (err != error.EndOfStream) {
            return err;
        }
    }
    const available_ids = try available_id_list.toOwnedSlice(allocator);
    
    return .{ .fresh_id_ranges = id_range_tree, .available_ids = available_ids };
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const num_fresh, const possible_fresh = try countFreshIngredientIDs(TEST_INPUT_FILEPATH, allocator);
    try std.testing.expect(num_fresh == 3);
    try std.testing.expect(possible_fresh == 14);
}
