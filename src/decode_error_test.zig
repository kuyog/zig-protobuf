const std = @import("std");
const protobuf = @import("protobuf.zig");
const wire = @import("wire.zig");
const allocator = std.testing.allocator;

const Child = struct {
    label: []const u8 = &.{},
    number: u32 = 0,

    pub const _desc_table = .{
        .label = protobuf.fd(1, .{ .scalar = .string }),
        .number = protobuf.fd(2, .{ .scalar = .uint32 }),
    };

    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        protobuf.deinit(gpa, self);
    }
};

const Choice = union(enum) {
    child: Child,
    text: []const u8,

    pub const _desc_table = .{
        .child = protobuf.fd(7, .submessage),
        .text = protobuf.fd(8, .{ .scalar = .string }),
    };
};

const Message = struct {
    label: []const u8 = &.{},
    children: std.ArrayList(Child) = .empty,
    numbers: std.ArrayList(u32) = .empty,
    strings: std.ArrayList([]const u8) = .empty,
    nested: ?Child = null,
    indirect: ?*Child = null,
    choice: ?Choice = null,
    number: u32 = 0,

    pub const _desc_table = .{
        .label = protobuf.fd(1, .{ .scalar = .string }),
        .children = protobuf.fd(2, .{ .repeated = .submessage }),
        .numbers = protobuf.fd(3, .{ .packed_repeated = .{ .scalar = .uint32 } }),
        .strings = protobuf.fd(4, .{ .repeated = .{ .scalar = .string } }),
        .nested = protobuf.fd(5, .submessage),
        .indirect = protobuf.fd(6, .submessage),
        .choice = protobuf.fd(null, .{ .oneof = Choice }),
        .number = protobuf.fd(9, .{ .scalar = .uint32 }),
    };

    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        protobuf.deinit(gpa, self);
    }
};

// Independent wire bytes cover each owned field kind before a later failure.
const complete = "\x0a\x01r" ++
    "\x12\x05\x0a\x01a\x10\x01" ++
    "\x12\x05\x0a\x01b\x10\x02" ++
    "\x1a\x02\x01\x02" ++
    "\x22\x01s" ++
    "\x2a\x05\x0a\x01n\x10\x03" ++
    "\x32\x05\x0a\x01p\x10\x04" ++
    "\x3a\x05\x0a\x01c\x10\x05" ++
    "\x48\x06";
const truncated_number = "\x48\x80";
const truncated_child = "\x12\x05\x0a\x01x\x10\x80";
const negative_length = "\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01";

fn expectFailure(
    comptime T: type,
    gpa: std.mem.Allocator,
    bytes: []const u8,
    expected: anyerror,
) !void {
    var reader: std.Io.Reader = .fixed(bytes);
    if (protobuf.decode(T, &reader, gpa)) |decoded| {
        var unexpected = decoded;
        defer protobuf.deinit(gpa, &unexpected);
        return error.ExpectedDecodeFailure;
    } else |err| {
        // Allocation-failure sweeps must see OOM rather than swallowing it as
        // the intended malformed-input outcome.
        if (err == error.OutOfMemory) return err;
        try std.testing.expectEqual(expected, err);
    }
}

fn decodeComplete(gpa: std.mem.Allocator) !void {
    var reader: std.Io.Reader = .fixed(complete);
    var decoded = try protobuf.decode(Message, &reader, gpa);
    defer decoded.deinit(gpa);
    try std.testing.expectEqualStrings("r", decoded.label);
    try std.testing.expectEqual(@as(usize, 2), decoded.children.items.len);
    try std.testing.expectEqualStrings("a", decoded.children.items[0].label);
    try std.testing.expectEqualStrings("b", decoded.children.items[1].label);
    try std.testing.expectEqual(@as(u32, 2), decoded.children.items[1].number);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2 }, decoded.numbers.items);
    try std.testing.expectEqual(@as(usize, 1), decoded.strings.items.len);
    try std.testing.expectEqualStrings("s", decoded.strings.items[0]);
    try std.testing.expectEqualStrings("n", decoded.nested.?.label);
    try std.testing.expectEqualStrings("p", decoded.indirect.?.label);
    try std.testing.expectEqualStrings("c", decoded.choice.?.child.label);
    try std.testing.expectEqual(@as(u32, 6), decoded.number);
}

fn decodeMalformed(gpa: std.mem.Allocator, bytes: []const u8) !void {
    try expectFailure(Message, gpa, bytes, error.EndOfStream);
}

test "decode ownership: valid owned fields survive until caller deinit" {
    try decodeComplete(allocator);
}

test "decode ownership: later scalar EOF releases all prior owned fields" {
    try decodeMalformed(allocator, complete ++ truncated_number);
}

test "decode ownership: complete message allocation failures release partial state" {
    try std.testing.checkAllAllocationFailures(allocator, decodeComplete, .{});
}

test "decode ownership: truncated repeated child allocation failures release partial state" {
    try std.testing.checkAllAllocationFailures(allocator, decodeMalformed, .{complete ++ truncated_child});
}

test "decode ownership: malformed merged submessages and oneof release partial state" {
    const suffixes = [_][]const u8{
        "\x2a\x05\x0a\x01x\x10\x80", // Existing inline submessage.
        "\x32\x05\x0a\x01x\x10\x80", // Existing pointer submessage.
        "\x3a\x05\x0a\x01x\x10\x80", // Existing oneof submessage.
        "\x42\x01t\x48\x80", // Replace the oneof, then fail later.
    };
    inline for (suffixes) |suffix| {
        try std.testing.checkAllAllocationFailures(allocator, decodeMalformed, .{complete ++ suffix});
    }
}

fn retainedChildRollback(gpa: std.mem.Allocator) !void {
    var message: Message = .{};
    defer message.deinit(gpa);
    try message.children.ensureTotalCapacity(gpa, 16);
    message.children.appendAssumeCapacity(.{ .label = try gpa.dupe(u8, "keep"), .number = 41 });
    const original_capacity = message.children.capacity;
    try std.testing.expect(original_capacity > message.children.items.len);

    var bad_reader: std.Io.Reader = .fixed(truncated_child);
    if (wire.decodeMessage(&message, gpa, &bad_reader, .{})) |_| {
        return error.ExpectedDecodeFailure;
    } else |err| {
        if (err == error.OutOfMemory) return err;
        try std.testing.expectEqual(error.EndOfStream, err);
    }
    try std.testing.expectEqual(@as(usize, 1), message.children.items.len);
    try std.testing.expectEqual(original_capacity, message.children.capacity);
    try std.testing.expectEqualStrings("keep", message.children.items[0].label);
    try std.testing.expectEqual(@as(u32, 41), message.children.items[0].number);

    var good_reader: std.Io.Reader = .fixed("\x12\x05\x0a\x01y\x10\x07");
    _ = try wire.decodeMessage(&message, gpa, &good_reader, .{});
    try std.testing.expectEqual(@as(usize, 2), message.children.items.len);
    try std.testing.expectEqualStrings("y", message.children.items[1].label);
    try std.testing.expectEqual(@as(u32, 7), message.children.items[1].number);
}

test "decode ownership: repeated child EOF preserves retained items with spare capacity" {
    try std.testing.checkAllAllocationFailures(allocator, retainedChildRollback, .{});
}

test "decode ownership: packed scalar EOF rolls back only appended values" {
    var message: Message = .{};
    defer message.deinit(allocator);
    try message.numbers.ensureTotalCapacity(allocator, 16);
    message.numbers.appendAssumeCapacity(41);
    const capacity = message.numbers.capacity;
    var reader: std.Io.Reader = .fixed("\x1a\x02\x01\x80");
    try std.testing.expectError(error.EndOfStream, wire.decodeMessage(&message, allocator, &reader, .{}));
    try std.testing.expectEqualSlices(u32, &.{41}, message.numbers.items);
    try std.testing.expectEqual(capacity, message.numbers.capacity);
}

test "decode ownership: repeated string EOF releases earlier strings" {
    try std.testing.checkAllAllocationFailures(allocator, decodeMalformed, .{complete ++ "\x22\x04x"});
}

test "decode ownership: packed scalar length overrun preserves retained values" {
    var message: Message = .{};
    defer message.deinit(allocator);
    try message.numbers.ensureTotalCapacity(allocator, 16);
    message.numbers.appendAssumeCapacity(41);
    var reader: std.Io.Reader = .fixed("\x1a\x01\x96\x01");
    try std.testing.expectError(error.InvalidInput, wire.decodeMessage(&message, allocator, &reader, .{}));
    try std.testing.expectEqualSlices(u32, &.{41}, message.numbers.items);
}

test "decode ownership: invalid packed enum preserves retained values" {
    const State = enum(i32) { first = 0, second = 1 };
    const EnumMessage = struct {
        states: std.ArrayList(State) = .empty,

        pub const _desc_table = .{
            .states = protobuf.fd(1, .{ .packed_repeated = .@"enum" }),
        };
    };
    var message: EnumMessage = .{};
    defer protobuf.deinit(allocator, &message);
    try message.states.ensureTotalCapacity(allocator, 16);
    message.states.appendAssumeCapacity(.first);
    var reader: std.Io.Reader = .fixed("\x0a\x02\x01\x02");
    try std.testing.expectError(error.InvalidInput, wire.decodeMessage(&message, allocator, &reader, .{}));
    try std.testing.expectEqualSlices(State, &.{.first}, message.states.items);
}

test "decode ownership: negative packed length is refused before allocation" {
    try expectFailure(Message, std.testing.failing_allocator, "\x1a" ++ negative_length, error.InvalidInput);
}

test "decode ownership: negative repeated child length is refused before allocation" {
    try expectFailure(Message, std.testing.failing_allocator, "\x12" ++ negative_length, error.InvalidInput);
}

test "decode ownership: negative repeated string length is refused before allocation" {
    try expectFailure(Message, std.testing.failing_allocator, "\x22" ++ negative_length, error.InvalidInput);
}

const OptionalLists = struct {
    numbers: ?std.ArrayList(u32) = null,
    children: ?std.ArrayList(Child) = null,

    pub const _desc_table = .{
        .numbers = protobuf.fd(1, .{ .packed_repeated = .{ .scalar = .uint32 } }),
        .children = protobuf.fd(2, .{ .repeated = .submessage }),
    };

    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        protobuf.deinit(gpa, self);
    }
};

fn optionalRollback(gpa: std.mem.Allocator, bytes: []const u8) !void {
    // Direct decodeMessage callers retain ownership of their initialized value.
    var message: OptionalLists = .{};
    defer message.deinit(gpa);
    var reader: std.Io.Reader = .fixed(bytes);
    if (wire.decodeMessage(&message, gpa, &reader, .{})) |_| {
        return error.ExpectedDecodeFailure;
    } else |err| {
        if (err == error.OutOfMemory) return err;
        try std.testing.expectEqual(error.EndOfStream, err);
    }
    try std.testing.expectEqual(@as(?std.ArrayList(u32), null), message.numbers);
    try std.testing.expectEqual(@as(?std.ArrayList(Child), null), message.children);
}

test "decode ownership: newly present optional packed list frees storage on rollback" {
    try std.testing.checkAllAllocationFailures(allocator, optionalRollback, .{"\x0a\x02\x01\x80"});
}

test "decode ownership: newly present optional repeated list frees storage on rollback" {
    try std.testing.checkAllAllocationFailures(allocator, optionalRollback, .{truncated_child});
}

test "decode ownership: valid optional lists remain caller-owned" {
    var message: OptionalLists = .{};
    defer message.deinit(allocator);
    var reader: std.Io.Reader = .fixed("\x0a\x02\x01\x02\x12\x05\x0a\x01z\x10\x03");
    _ = try wire.decodeMessage(&message, allocator, &reader, .{});
    try std.testing.expectEqualSlices(u32, &.{ 1, 2 }, message.numbers.?.items);
    try std.testing.expectEqual(@as(usize, 1), message.children.?.items.len);
    try std.testing.expectEqualStrings("z", message.children.?.items[0].label);
}
