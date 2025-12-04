const std = @import("std");

const INPUT_FILEPATH = "input.txt";
const BUF_SIZE: usize = 1024;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var id_ranges = try IdRange.allocFromFile(INPUT_FILEPATH, allocator);
    defer id_ranges.deinit(allocator);

    var invalid_id_sum: u64 = 0;
    for (try id_ranges.toOwnedSlice(allocator)) |id_range| {
        invalid_id_sum += try id_range.getInvalidIdSum();
    }

    var writer_buf: [BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Invalid ID sum is: {d}\n", .{invalid_id_sum});
    try stdout_writer.flush();
}

const IdRange = struct {
    min_id: []const u8,
    max_id: []const u8,

    fn allocFromFile(filepath: []const u8, allocator: std.mem.Allocator) !IdRangeList {
        var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
        defer input_file.close();

        var reader_buf: [BUF_SIZE]u8 = undefined;
        var file_reader = input_file.reader(&reader_buf);
        var reader = &file_reader.interface;

        var id_range_list: IdRangeList = .empty;
        while (true) {
            const range_str: []u8 = reader.takeDelimiterExclusive(',') catch |err| {
                if (err == error.EndOfStream) {
                    break;
                }
                return err;
            };
            const range_str_len = if (!file_reader.atEnd()) end: {
                reader.toss(1);
                break :end range_str.len;
            } else not_end: {
                break :not_end range_str.len - 1;
            };

            const separator_index: usize = std.mem.indexOf(u8, range_str, "-").?;
            const id_range = IdRange{ .min_id = try allocator.dupe(u8, range_str[0..separator_index]), .max_id = try allocator.dupe(u8, range_str[separator_index + 1 .. range_str_len]) };

            try id_range_list.append(allocator, id_range);
        }

        return id_range_list;
    }

    fn getInvalidIdSum(self: *const IdRange) !u64 {
        // Check the number of digits, since odd digits cannot repeat patterns twice.
        const min_val_digits: usize = self.min_id.len;
        const odd_min_val_digits: bool = isOdd(min_val_digits);

        const max_val_digits: usize = self.max_id.len;
        const odd_max_val_digits: bool = isOdd(max_val_digits);

        if (min_val_digits == max_val_digits and odd_min_val_digits and odd_max_val_digits) {
            return 0;
        }

        var invalidIdSum: u64 = 0;
        const min_val = try std.fmt.parseInt(u64, self.min_id, 10);
        const max_val = try std.fmt.parseInt(u64, self.max_id, 10);
        for (min_val_digits..max_val_digits + 1) |i| {
            if (isOdd(i)) {
                continue;
            }

            const index_u64 = @as(u64, i);
            const base_id: u64 = if (i == min_val_digits) min_val else std.math.pow(u64, 10, index_u64 - 1);
            const max_id: u64 = if (i == max_val_digits) max_val else std.math.pow(u64, 10, index_u64) - 1;

            const mid_index: usize = i / 2;
            for (base_id..max_id + 1) |j| {
                var buf: [BUF_SIZE]u8 = undefined;
                const bytes = std.fmt.printInt(&buf, j, 10, .lower, .{});

                if (std.mem.eql(u8, buf[0..mid_index], buf[mid_index..bytes])) {
                    invalidIdSum += j;
                }
            }
        }

        return invalidIdSum;
    }
};

inline fn isOdd(num: usize) bool {
    return num % 2 == 1;
}

const IdRangeList = std.ArrayList(IdRange);

test "Example Test" {}
