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
    const total_output_joltage = try calcTotalOutputJoltage(input_filepath, allocator);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Total output joltage is: {d}\n", .{total_output_joltage});
    try stdout_writer.flush();
}

fn calcTotalOutputJoltage(input_filepath: []const u8, allocator: Allocator) !u32 {
    const banks: Banks = try readBanksFromFile(input_filepath, allocator);

    var total_output_joltage: u32 = 0;
    for (banks) |bank| {
       total_output_joltage += try calcMaxBankJoltage(bank);
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

fn calcMaxBankJoltage(bank: []const u8) !u8 {
    var max_rating: [2]u8 = undefined;
    max_rating[0] = bank[bank.len - 2];
    max_rating[1] = bank[bank.len - 1];

    var i: usize = bank.len - 2;
    while (i > 0) {
        i -= 1; 
        const battery_rating = bank[i];

        const curr_leading_digit = max_rating[0];
        if (battery_rating >= curr_leading_digit) {
            if (curr_leading_digit > max_rating[1]) {
                max_rating[1] = curr_leading_digit;
            }
            
            max_rating[0] = battery_rating;
        }

        if (std.mem.eql(u8, &max_rating, "99")) break;
    }

    return try std.fmt.parseInt(u8, &max_rating, 10);
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const total_output_joltage = try calcTotalOutputJoltage(TEST_INPUT_FILEPATH, allocator);
    try std.testing.expect(total_output_joltage == 357);
}

