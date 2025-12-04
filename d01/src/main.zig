const std = @import("std");

// Constants //
const FILE_PATH = "input.txt";
const NUM_DIALS: u8 = 100;
const STARTING_NUMBER: u8 = 50;
const BUF_SIZE: usize = 1024;

// Types //
const Direction = enum {
    left,
    right,

    fn fromChar(direction_char: u8) !Direction {
        switch (direction_char) {
            'L' => return .left,
            'R' => return .right,
            else => {
                std.debug.print("Invalid direction character: {}\n", .{direction_char});
                return error.InvalidChar;
            },
        }
    }
};

const Instruction = struct {
    direction: Direction,
    num_turns: u16,

    fn allocFromFile(file_path: []const u8, allocator: std.mem.Allocator) !InstructionList {
        const instructions_file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
        defer instructions_file.close();

        var reader_buf: [BUF_SIZE]u8 = undefined;
        var file_reader = instructions_file.reader(&reader_buf);
        var reader = &file_reader.interface;

        var instructions: InstructionList = .empty;
        while (true) {
            const direction_char: u8 = reader.takeByte() catch |err| {
                if (err == error.EndOfStream) {
                    break;
                }

                return err;
            };

            const direction = try Direction.fromChar(direction_char);

            const num_turns_str: []u8 = try reader.takeDelimiterExclusive('\n');
            const num_turns: u16 = try std.fmt.parseInt(u16, num_turns_str, 10);
            reader.toss(1);

            const instruction = Instruction{ .direction = direction, .num_turns = num_turns };
            try instructions.append(allocator, instruction);
        }

        return instructions;
    }
};
const InstructionList = std.ArrayList(Instruction);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var instructions: InstructionList = try Instruction.allocFromFile(FILE_PATH, allocator);
    defer instructions.deinit(allocator);

    var curr_num: u8 = STARTING_NUMBER;
    var zero_clicks: u16 = 0;
    var num_zeroes: u16 = 0;
    for (try instructions.toOwnedSlice(allocator)) |instruction| {
        const dial_result = turn_dial(curr_num, instruction);
        curr_num = dial_result[0];
        zero_clicks += dial_result[1];
        
        if (curr_num == 0) {
            num_zeroes += 1;
        }
    }

    var writer_buf: [BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Part one code is: {d}\n", .{num_zeroes});
    try stdout_writer.print("Part two code is {d}\n", .{zero_clicks});
    try stdout_writer.flush();
}

fn turn_dial(curr_num: u8, instruction: Instruction) struct {u8, u8} { 
    const num_turns: u16 = instruction.num_turns;
    if (num_turns == 0) {
        return .{curr_num, 0};
    }

    // Calculate full rotations and remaining turns
    const effective_turns: u8 = @truncate(num_turns % NUM_DIALS);
    var zero_clicks: u8 = @truncate(@divFloor(num_turns, NUM_DIALS));
    if (effective_turns == 0) {
        return .{curr_num, zero_clicks};
    }

    const new_num: u8 = if (instruction.direction == .left) left: {
        if (curr_num <= effective_turns and curr_num != 0) {
            zero_clicks += 1;
        }

        break :left @truncate((curr_num + NUM_DIALS - effective_turns) % NUM_DIALS);
    } else right: {
        const raw_turn_total: u8 = curr_num + effective_turns;
        if (raw_turn_total >= NUM_DIALS and curr_num != 0) {
            zero_clicks += 1;
        }

        break :right @truncate(raw_turn_total % NUM_DIALS);
    };

    return .{new_num, zero_clicks};
}
