const std = @import("std");
const zbox = @import("zbox");

memory: [256]u8,
cursor: u8 = 0, // Instruction pointer.

pub fn move_up(self: *@This()) void {
    self.cursor -%= bytes_per_row;
}
pub fn move_down(self: *@This()) void {
    self.cursor +%= bytes_per_row;
}
pub fn move_left(self: *@This()) void {
    self.cursor -%= 1;
}
pub fn move_right(self: *@This()) void {
    self.cursor +%= 1;
}
pub fn inc(self: *@This()) void {
    self.memory[self.cursor] +%= 1;
}
pub fn dec(self: *@This()) void {
    self.memory[self.cursor] -%= 1;
}
pub fn enter(self: *@This(), char: u8) void {
    self.memory[self.cursor] = char;
    self.move_right();
    return;
}
pub fn backspace(self: *@This()) void {
    self.move_left();
    self.memory[self.cursor] = 0;
}

const Instruction = union(enum) {
    noop,
    halt,
    jump: u8, // target
    add: [3]u8, // two summands, output

    const Self = @This();
    pub fn parse(a: u8, b: u8, c: u8, d: u8) !Self {
        return switch (a) {
            0 => .noop,
            1 => .halt,
            2 => Instruction{ .jump = b },
            3 => Instruction{ .add = .{b, c, d} },
            else => error.InvalidInstruction,
        };
    }

    pub fn len(self: Self) u8 {
        return switch (self) {
            .noop => 1,
            .halt => 1,
            .jump => 2,
            .add => 4,
        };
    }
};

pub fn current_instruction(self: @This()) !Instruction {
    return Instruction.parse(
        self.memory[self.cursor],
        self.memory[self.cursor +% 1],
        self.memory[self.cursor +% 2],
        self.memory[self.cursor +% 3],
    );
}

pub fn run(self: *@This()) !void {
    const instruction = try self.current_instruction();
    switch (instruction) {
        .noop => {},
        .halt => return,
        .jump => |target| {
            self.cursor = target;
            return;
        },
        .add => |args| {
            const a = self.memory[args[0]];
            const b = self.memory[args[1]];
            self.memory[args[2]] = a + b;
        },
    }
    self.cursor +%= instruction.len();
}

// Stuff for displaying the VM.

const bytes_per_row = 16;

pub fn dump(self: @This()) void {
    for (0..(256 / bytes_per_row)) |i| {
        // Hex part
        for (0..bytes_per_row) |j| {
            const pos = i * bytes_per_row + j;
            if (pos == self.cursor) {
                std.debug.print("[", .{});
            } else if (pos == self.cursor + 1) {
                std.debug.print("]", .{});
            } else {
                std.debug.print(" ", .{});
            }
            std.debug.print("{x:2}", .{self.memory[pos]});
        }
        if ((i + 1) * bytes_per_row == self.cursor + 1) {
            std.debug.print("]", .{});
        } else {
            std.debug.print(" ", .{});
        }
        std.debug.print(" ", .{});

        // ASCII part
        for (0..bytes_per_row) |j| {
            const pos = i * bytes_per_row + j;
            const char = switch (self.memory[pos]) {
                32...126 => self.memory[pos],
                else => '.',
            };
            std.debug.print("{c}", .{char});
        }

        std.debug.print("\n\r", .{});
    }
}

pub fn dump_to_buffer(self: @This(), buffer: *zbox.Buffer) void {
    // The hex view.
    for (0.., self.memory) |i, byte| {
        const x = i % bytes_per_row * 3 + 1;
        const y = i / bytes_per_row;

        const is_cursor = i == self.cursor;
        const hex_chars = "0123456789abcdef";

        buffer.cellRef(y, x).* = .{
            .char = hex_chars[byte / 16],
            .attribs = .{ .reverse = is_cursor },
        };
        buffer.cellRef(y, x + 1).* = .{
            .char = hex_chars[byte % 16],
            .attribs = .{ .reverse = is_cursor },
        };
    }

    // The ASCII view.
    for (0.., self.memory) |i, byte| {
        const x = i % bytes_per_row + 50;
        const y = i / bytes_per_row;

        const char = switch (byte) {
            32...126 => byte,
            else => '.',
        };
        buffer.cellRef(y, x).* = .{ .char = char };
    }
}
