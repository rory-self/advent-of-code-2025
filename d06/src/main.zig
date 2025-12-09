const std = @import("std");

const IO_BUF_SIZE: usize = 128;
const TEST_INPUT_FILEPATH = "test.txt";

const Allocator = std.mem.Allocator;
const Operator = enum {
    multiply,
    add,

    fn fromChar(char: u8) !Operator {
        return switch (char) {
            '+' => .add,
            '*' => .multiply,
            else => error.InvalidOperator,
        };
    }
};

const Problem = struct {
    numbers: std.ArrayList(u32) = .empty,
    operator: Operator,

    fn eval(self: *const Problem) u128 {
        var answer: u128 = 1;
        for (self.numbers.items) |number| {
            switch (self.operator) {
                .add => answer += number,
                .multiply => answer *= number,
            }
        }

        if (self.operator == .add) {
            answer -= 1;
        }

        return answer;
    }
};
const Problems = []const Problem;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArg;

    const answer_total, const ceph_answer = try calcAnswerTotal(input_filepath, allocator);

    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_file_writer = std.fs.File.stdout().writer(&writer_buf);
    var stdout_writer = &stdout_file_writer.interface;
    try stdout_writer.print("Answer sum is: {d}\n", .{answer_total});
    try stdout_writer.print("Ceph sum is: {}\n", .{ceph_answer});
    try stdout_writer.flush();
}

fn calcAnswerTotal(input_filepath: []const u8, allocator: Allocator) !struct { u128, u128 } {
    const normal_problems, _ = try readProblemsFromFile(input_filepath, allocator);

    var answer_sum: u128 = 0;
    for (normal_problems) |problem| {
        answer_sum += problem.eval();
    }

    return .{ answer_sum, 0 };
}

fn readProblemsFromFile(
    filepath: []const u8,
    allocator: Allocator,
) !struct { Problems, Problems } {
    var file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();
    var reader_buf: [IO_BUF_SIZE]u8 = undefined;
    var reader = file.reader(&reader_buf);

    const normal_problems = try readNormalProblems(&reader, allocator);
    const cephalopod_problems: Problems = undefined;

    return .{ normal_problems, cephalopod_problems };
}

fn readNormalProblems(reader: *std.fs.File.Reader, allocator: Allocator) !Problems {
    const max_digits = try countMaxDigits(reader);
    const line_length = try countLineLength(reader);
    const num_problems = line_length / (max_digits + 1);

    const interface = &reader.interface;
    const problems = try allocator.alloc(Problem, num_problems);
    for (0..problems.len) |i| {
        try reader.seekTo(i * (max_digits + 1));
        problems[i].numbers = .empty;

        while (true) {
            const first_char = try interface.peekByte();
            if (Operator.fromChar(first_char)) |operator| {
                problems[i].operator = operator;
                break;
            } else |_| {}

            const term = try allocator.alloc(u8, max_digits);
            for (0..max_digits) |j| {
                term[j] = try interface.takeByte();
            }

            const trimmed_term = std.mem.trim(u8, term, " ");
            const parsed_num = try std.fmt.parseInt(u32, trimmed_term, 10);
            try problems[i].numbers.append(allocator, parsed_num);

            const next_num_offset: i64 = @intCast(line_length - max_digits);
            try reader.seekBy(next_num_offset);
        }
    }

    return problems;
}

fn countMaxDigits(reader: *std.fs.File.Reader) !usize {
    const interface = &reader.interface;

    var num_digits: usize = 0;
    var hit_digit = false;
    while (interface.takeByte()) |char| {
        if (char == '\n') {
            break;
        }

        if (char != ' ') {
            hit_digit = true;
        } else if (hit_digit) {
            break;
        }

        num_digits += 1;
    } else |err| {
        return err;
    }

    try reader.seekTo(0);
    return num_digits;
}

fn countLineLength(reader: *std.fs.File.Reader) !usize {
    const interface = &reader.interface;

    var line_length: usize = 0;
    while (interface.takeByte()) |char| {
        line_length += 1;

        if (char == '\n') {
            break;
        }
    } else |err| {
        return err;
    }

    try reader.seekTo(0);
    return line_length;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const answer_total, const ceph_answer = try calcAnswerTotal(TEST_INPUT_FILEPATH, allocator);
    try std.testing.expect(answer_total == 4277556);
    try std.testing.expect(ceph_answer == 3263827);
}
