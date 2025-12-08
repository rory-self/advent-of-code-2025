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
        var range = self.range;

        if (new_min_id < range.min_id and new_max_id > range.max_id) {
            self.range = collapseTree(&self.left, new_range);
            self.range = collapseTree(&self.right, new_range);
            return;
        } else if (range.idInRange(new_min_id) and new_max_id > range.max_id) {
            range.max_id = new_range.max_id;
            self.range = collapseTree(&self.right, range);
            return;
        } else if (range.idInRange(new_max_id) and new_min_id < range.min_id) {
            range.min_id = new_range.min_id;
            self.range = collapseTree(&self.left, range);
            return;
        } else if (range.idInRange(new_max_id) and range.idInRange(new_min_id)) {
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

    fn collapseTree(node: *?*RangeTreeNode, range: FreshRange) FreshRange {
        if (node.*) |curr_node| {
            const curr_range = curr_node.range;
            const curr_max = curr_range.max_id;
            const curr_min = curr_range.min_id;
            if (range.min_id > curr_max) {
                return collapseTree(&curr_node.right, range);
            } else if (range.max_id < curr_min) {
                return collapseTree(&curr_node.left, range);
            }

            var new_range = range;
            if (curr_range.idInRange(range.max_id)) {
                new_range.max_id = curr_max;
                node.* = curr_node.right;
            } else {
                new_range.min_id = curr_min;
                node.* = curr_node.left;
            }

            return new_range;
        }

        return range;
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

    fn countIDs(self: *const RangeTreeNode) u64 {
        var num_ids: u64 = @intCast(self.range.max_id - self.range.min_id + 1);
        if (self.left) |left_node| {
            num_ids += left_node.countIDs();
        }

        if (self.right) |right_node| {
            num_ids += right_node.countIDs();
        }
        return num_ids;
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

    pub fn countIDs(self: *const RangeTree) u64 {
        if (self.head) |head_range| {
            return head_range.countIDs();
        } else {
            return 0;
        }
    }
};
