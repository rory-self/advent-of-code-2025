const std = @import("std");

const Allocator = std.mem.Allocator;

pub const FreshRange = struct {
    min_id: u64,
    max_id: u64,

    pub fn fromString(string: []const u8) !FreshRange {
        const separator_index = std.mem.indexOf(u8, string, "-") orelse return error.MissingDelimiter;
        const min_id = string[0..separator_index];
        const max_id = string[separator_index + 1 ..];

        const min_val = try std.fmt.parseInt(u64, min_id, 10);
        const max_val = try std.fmt.parseInt(u64, max_id, 10);
        return .{ .min_id = min_val, .max_id = max_val };
    }

    inline fn idInRange(self: *const FreshRange, id: u64) bool {
        return id >= self.min_id and id <= self.max_id;
    }
};

const RangeTreeNode = struct {
    range: FreshRange,
    left: ?*RangeTreeNode,
    right: ?*RangeTreeNode,

    fn fromRange(range: FreshRange, allocator: Allocator) !*RangeTreeNode {
        var new_node = try allocator.create(RangeTreeNode);
        new_node.range = range;
        new_node.left = null;
        new_node.right = null;

        return new_node;
    }

    fn doInsertRange(
        self: *RangeTreeNode,
        new_range: FreshRange,
        allocator: Allocator,
    ) !void {
        const new_min_id = new_range.min_id;
        const new_max_id = new_range.max_id;
        const range = self.range;

        if (new_min_id < range.min_id and new_max_id > range.max_id) {
            self.range = new_range;
            collapseTreeLeft(self, new_min_id);
            collapseTreeRight(self, new_max_id);
            return;
        } else if (range.idInRange(new_min_id) and new_max_id > range.max_id) {
            self.range.max_id = new_max_id;
            collapseTreeRight(self, new_max_id);
            return;
        } else if (range.idInRange(new_max_id) and new_min_id < range.min_id) {
            self.range.min_id = new_min_id;
            collapseTreeLeft(self, new_min_id);
            return;
        }

        if (new_max_id < range.min_id) {
            if (self.left) |left_node| {
                try left_node.doInsertRange(new_range, allocator);
                return;
            }

            self.left = try RangeTreeNode.fromRange(new_range, allocator);
            return;
        }

        if (self.right) |right_node| {
            try right_node.doInsertRange(new_range, allocator);
            return;
        }

        self.right = try RangeTreeNode.fromRange(new_range, allocator);
    }

    fn collapseTreeLeft(self: *RangeTreeNode, min_bound: u64) void {
        while (self.left) |left_node| {
            if (left_node.range.max_id < min_bound) {
                break;
            }

            self.range.min_id = left_node.range.min_id;
            self.left = left_node.left;
        }
    }

    fn collapseTreeRight(self: *RangeTreeNode, max_bound: u64) void {
        while (self.right) |right_node| {
            if (right_node.range.min_id > max_bound) {
                break;
            }

            self.range.max_id = right_node.range.max_id;
            self.right = right_node.right;
        }
    }

    fn idInRange(self: *const RangeTreeNode, id: u64) bool {
        const range = self.range;
        if (range.idInRange(id)) {
            return true;
        }

        if (range.min_id > id) {
            if (self.left) |left_node| {
                return left_node.idInRange(id);
            }
            return false;
        }

        if (self.right) |right_node| {
            return right_node.idInRange(id);
        }
        return false;
    }
};

pub const RangeTree = struct {
    head: ?*RangeTreeNode,

    pub const empty = RangeTree{
        .head = null,
    };

    pub fn insertRange(
        self: *RangeTree,
        new_range: FreshRange,
        allocator: Allocator,
    ) !void {
        if (self.head) |head_range| {
            try head_range.doInsertRange(new_range, allocator);
        } else {
            self.head = try RangeTreeNode.fromRange(new_range, allocator);
        }
    }

    pub fn idInRange(self: *const RangeTree, id: u64) bool {
        if (self.head) |head_range| {
            return head_range.idInRange(id);
        }
        return false;
    }
};
