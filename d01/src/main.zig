const std = @import("std");

// Constants //
const FILE_PATH = "input.txt";
const MAX_TURNS_DIGITS = 2;
const NUM_DIALS = 100;
const STARTING_NUMBER = 50;
const BUF_SIZE = 1024;

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
    var num_zeroes: u16 = 0;
    for (try instructions.toOwnedSlice(allocator)) |instruction| {
        curr_num = turn_dial(curr_num, instruction, &num_zeroes);
        // std.debug.print("z: {} n: {}\n", .{num_zeroes, curr_num});
    }

    var writer_buf: [BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("The code is: {d}\n", .{num_zeroes});
    try stdout_writer.flush();
}

fn turn_dial(curr_num: u8, instruction: Instruction, num_zeroes: *u16) u8 { 
    const num_turns: u16 = instruction.num_turns;
    if (num_turns == 0) {
        return curr_num;
    }

    const effective_turns: u8 = @truncate(num_turns % NUM_DIALS);
    const full_rotations: u16 = @divFloor(num_turns, NUM_DIALS);
    if (full_rotations > 0) {
        num_zeroes.* += if (curr_num == 0 and effective_turns == 0) full_rotations - 1 else full_rotations;
    }

    if (instruction.direction == .left) {
        if (curr_num <= effective_turns and curr_num != 0) {
            num_zeroes.* += 1;
        }

        return @truncate((curr_num + NUM_DIALS - effective_turns) % NUM_DIALS);
    }

    const raw_turn_total: u8 = curr_num + effective_turns;
    if (raw_turn_total >= NUM_DIALS and curr_num != 0) {
        num_zeroes.* += 1;
    }

    return @truncate(raw_turn_total % NUM_DIALS);
}
