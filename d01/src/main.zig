const std = @import("std");

const FILE_PATH = "input.txt";
const MAX_TURNS_DIGITS = 2;
const NUM_DIALS = 100;
const STARTING_NUMBER = 50;
const BUF_SIZE = 1024;

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
            const num_turns = try std.fmt.parseInt(u16, num_turns_str, 10);
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
    var num_zeroes: u64 = 0;
    for (try instructions.toOwnedSlice(allocator)) |instruction| {
        curr_num = turn_dial(curr_num, instruction);
        if (curr_num == 0) {
            num_zeroes += 1;
        }
    }

    var writer_buf: [BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("The code is: {d}\n", .{num_zeroes});
    try stdout_writer.flush();
}

fn turn_dial(curr_num: u8, instruction: Instruction) u8 {
    const effective_turns: u8 = @truncate(instruction.num_turns % NUM_DIALS);
    if (instruction.direction == .left) {
        return @truncate((curr_num + NUM_DIALS - effective_turns) % NUM_DIALS);
    } 
    
    return @truncate((curr_num + effective_turns) % NUM_DIALS);
}

