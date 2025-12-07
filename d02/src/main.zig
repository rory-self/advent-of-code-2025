//! 'Advent of Code' day 2 solution by Rory Self
const std = @import("std");

// Constants //
const INPUT_FILEPATH = "input.txt";
const TEST_FILEPATH = "test.txt";
const IO_BUF_SIZE: usize = 1024;
const MIN_REPEATS: u8 = 2;

// Aliases //
const DigitPatternLenMap = std.hash_map.AutoHashMap(usize, []usize);
const Allocator = std.mem.Allocator;

const Pow = std.math.pow;

// Types //
const IdCategory = enum {
    valid,
    p1_invalid,
    p2_invalid
};

// Implementation //
pub fn main() !void {
    const id_sum_p1, const id_sum_p2 = try invalidIdSumsFromFile(INPUT_FILEPATH);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Invalid ID sum is: {d} (Max 2 repeats)\n", .{id_sum_p1});
    try stdout_writer.print("Invalid ID sum is: {d} (Unlimited repeats)\n", .{id_sum_p2});
    try stdout_writer.flush();
}

/// Given a valid path to a file storing the puzzle input, calculates and returns the invalid id
/// sums for each part.
fn invalidIdSumsFromFile(filepath: []const u8) !struct { u64, u64 } {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_ranges: []const IdRange = try idRangesFromFile(filepath, allocator);
    defer allocator.free(id_ranges);

    // Instantiate a map that tracks applicable pattern lengths for a given
    // number of digits. i.e. all factors of the number of digits.
    var pattern_lens_by_digits = DigitPatternLenMap.init(allocator);
    defer pattern_lens_by_digits.deinit();

    var total_sum_p1: u64 = 0;
    var total_sum_p2: u64 = 0;
    for (id_ranges) |id_range| {
        const sum_p1, const sum_p2 = try id_range.calcInvalidIdSums(&pattern_lens_by_digits, allocator);
        total_sum_p1 += sum_p1;
        total_sum_p2 += sum_p2;
    } 

    return .{total_sum_p1, total_sum_p2};
}

/// Given a valid path to a file containing the puzzle input, returns a slice containing all the
/// id ranges to check formatted into IdRange structs. Requires valid allocator parameter.
fn idRangesFromFile(filepath: []const u8, allocator: Allocator) ![]const IdRange {
    var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer input_file.close();
                                                                                                                                                                                        
    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var file_reader = input_file.reader(&reader_buf);
    var reader = &file_reader.interface;
                                                                                                                                                                                        
    var id_range_list: std.ArrayList(IdRange) = .empty;
    errdefer id_range_list.deinit(allocator);

    while (true) {
        const range_str: []u8 = reader.takeDelimiterExclusive(',') catch |err| {
            if (err == error.EndOfStream) {
                break;
            }
            return err;
        };
        const range_str_len = if (file_reader.atEnd()) end: {
            break :end range_str.len - 1;
        } else not_end: {
            reader.toss(1);
            break :not_end range_str.len;
        };
                                                                                                                                                                                        
        const separator_index: usize = std.mem.indexOf(u8, range_str, "-")
            orelse return error.MissingDelimiter;
        const min_id = range_str[0..separator_index];
        const max_id = range_str[separator_index + 1..range_str_len];
        
        const min_val = try std.fmt.parseInt(u64, min_id, 10);
        const max_val = try std.fmt.parseInt(u64, max_id, 10);

        const id_range = IdRange{ .min_id = min_val, .max_id = max_val };                                                                                                                                                                             
        try id_range_list.append(allocator, id_range);
    }
                                                                                                                                                                                        
    return try id_range_list.toOwnedSlice(allocator);
}

const IdRange = struct {
    min_id: u64,
    max_id: u64, 
    
    fn calcInvalidIdSums(
        self: *const IdRange,
        pattern_lengths_by_digit: *DigitPatternLenMap,
        allocator: Allocator
    ) !struct { u64, u64 } {
        const min_digits: u8 = countDigits(self.min_id);
        const max_digits: u8 = countDigits(self.max_id);

        var invalid_id_sum_p1: u64 = 0;
        var invalid_id_sum_p2: u64 = 0;
        for (min_digits..max_digits + 1) |i| {
            if (i == 1) {
                continue;
            }

            const digit_length_pair = try pattern_lengths_by_digit.getOrPut(i);
            const length_ptr = digit_length_pair.value_ptr;
            if (!digit_length_pair.found_existing) {
                length_ptr.* = try calcPossiblePatternLengths(i, allocator);
            }
            const pattern_lengths: []usize = length_ptr.*;
            
            const padded_index = @as(u64, i);
            const base_id: u64 = if (i == min_digits) self.min_id else Pow(u64, 10, padded_index - 1);
            const max_id: u64 = if (i == max_digits) self.max_id else Pow(u64, 10, padded_index) - 1;

            for (base_id..max_id + 1) |j| {
                const id_category: IdCategory = try checkId(j, i, pattern_lengths, allocator);
                switch (id_category) {
                    .valid => continue,
                    .p1_invalid => invalid_id_sum_p1 += j,
                    else => {},
                }

                invalid_id_sum_p2 += j;
            }
        }

        return .{ invalid_id_sum_p1, invalid_id_sum_p2 };
    }
};

fn countDigits(num: u64) u8 {
    var num_digits: u8 = 0;
    var mutated_num = num;
    while (mutated_num > 0) {
        mutated_num /= 10;
        num_digits += 1;
    }

    return num_digits;
}

fn calcPossiblePatternLengths(num_digits: usize, allocator: Allocator) ![]usize {
    var lengths: std.ArrayList(usize) = .empty;

    for (1..num_digits) |i| {
       if (num_digits % i == 0) {
            try lengths.append(allocator, i);
       }
    }

    return try lengths.toOwnedSlice(allocator);
}

fn checkId(
    id: u64,
    num_digits: usize,
    pattern_lengths: []const usize,
    allocator: Allocator
) !IdCategory {
    const digits: []const u8 = try collectDigits(id, num_digits, allocator);
    defer allocator.free(digits);

    var i: usize = pattern_lengths.len;
    while (i > 0) {
        i -= 1;

        const pattern_length = pattern_lengths[i];
        var sampled_pattern = try allocator.alloc(usize, pattern_length);
        defer allocator.free(sampled_pattern);
        
        for (0..pattern_length) |j| {
            sampled_pattern[j] = digits[j];
        }

        var curr_pattern_pos: usize = 0;
        var pattern_matches: bool = true;
        for (pattern_length..digits.len) |j| {
            const pattern_digit: u8 = @truncate(sampled_pattern[curr_pattern_pos]);
            if (pattern_digit != digits[j]) {
                pattern_matches = false;
                break;
            }
            curr_pattern_pos = (curr_pattern_pos + 1) % pattern_length;
        }

        if (pattern_matches) {
            return if (pattern_length == num_digits / 2 and num_digits % 2 == 0) .p1_invalid else .p2_invalid; 
        }
    }

    return .valid;
}

fn collectDigits(num: u64, num_digits: usize, allocator: Allocator) ![]const u8 {
    var carry_num: u64 = num;
 
    var digits = try allocator.alloc(u8, num_digits);
    for (0..num_digits) |i| {
        const magnitude = Pow(u64, 10, num_digits - i - 1);
        const digit = @divFloor(carry_num, magnitude);
        digits[i] = @truncate(digit);
 
        carry_num -= digit * magnitude;
    }
    return digits;
}


// Tests //
test "Example Test" {
    const p1_sum, const p2_sum = try invalidIdSumsFromFile(TEST_FILEPATH);
    try std.testing.expect(p1_sum == 1227775554);
    try std.testing.expect(p2_sum == 4174379265);
}
