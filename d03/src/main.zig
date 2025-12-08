const std = @import("std");

const TEST_INPUT_FILEPATH = "test.txt";
const IO_BUF_SIZE: usize = 1024;

const Banks = []const []const u8;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();

    const input_filepath = args.next() orelse return error.MissingArg;
    const total_output_joltage_p1 = try calcTotalOutputJoltage(input_filepath, allocator, 2);
    const total_output_joltage_p2 = try calcTotalOutputJoltage(input_filepath, allocator, 12);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Total output joltage (two batteries/bank) is: {d}\n", .{total_output_joltage_p1});
    try stdout_writer.print("Total output joltage (twelve batteries/bank) is {d}\n", .{total_output_joltage_p2});
    try stdout_writer.flush();
}

fn calcTotalOutputJoltage(
    input_filepath: []const u8,
    allocator: Allocator,
    batteries_per_bank: u8
) !u64 {
    const banks: Banks = try readBanksFromFile(input_filepath, allocator);

    var total_output_joltage: u64 = 0;
    for (banks) |bank| {
       total_output_joltage += try calcMaxBankJoltage(bank, batteries_per_bank, allocator);
    }

    return total_output_joltage;
}

fn readBanksFromFile(filepath: []const u8, allocator: std.mem.Allocator) !Banks {
    var input_file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer input_file.close();
                                                                                                                                                                                        
    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var file_reader = input_file.reader(&reader_buf);
    var reader = &file_reader.interface;
                                                                                                                                                                                        
    var bank_list: std.ArrayList([]const u8) = .empty;

    while (true) {
        const bank_str = reader.takeDelimiterExclusive('\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        reader.toss(1);

        const bank_dupe = try allocator.dupe(u8, bank_str);
        try bank_list.append(allocator, bank_dupe);
    }

    return try bank_list.toOwnedSlice(allocator);
}

fn calcMaxBankJoltage(
    bank: []const u8, 
    num_batteries: u8,
    allocator: Allocator,
) !u64 {
    if (bank.len < num_batteries) {
        return error.InsufficientBatteries;
    }

    var max_rating = try allocator.alloc(u8, num_batteries);
    for (0..num_batteries) |i| {
        max_rating[num_batteries - i - 1] = bank[bank.len - i - 1];
    }

    const max_possible_joltage = try allocator.alloc(u8, num_batteries);
    @memset(max_possible_joltage, '9');
    if (std.mem.eql(u8, max_rating, max_possible_joltage)) {
        return try std.fmt.parseInt(u64, max_rating, 10);
    }

    for (num_batteries..bank.len) |i| {
        const battery_rating = bank[bank.len - i - 1];

        var prev_digit = battery_rating;
        for (0..num_batteries) |j| {
            if (prev_digit < max_rating[j]) break;

            std.mem.swap(u8, &prev_digit, &max_rating[j]);
        }

        if (std.mem.eql(u8, max_rating, max_possible_joltage)) break;
    }

    return try std.fmt.parseInt(u64, max_rating, 10);
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const total_output_joltage_p1 = try calcTotalOutputJoltage(TEST_INPUT_FILEPATH, allocator, 2);
    try std.testing.expect(total_output_joltage_p1 == 357);

    const total_output_joltage_p2 = try calcTotalOutputJoltage(TEST_INPUT_FILEPATH, allocator, 12);
    try std.testing.expect(total_output_joltage_p2 == 3121910778619);
}

