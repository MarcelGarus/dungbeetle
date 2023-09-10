const std = @import("std");
const zbox = @import("zbox");

memory: [256]u8,
cursor: u8 = 0, // Instruction pointer.

// const Instruction = enum {
//     Noop,
//     Halt,
//     Jump(u8),
// };

pub fn run(self: *@This()) !void {
    switch (self.memory[self.cursor]) {
        0 => {
            // Noop instruction.
        },
        1 => {
            // Halt instruction.
            return;
        },
        else => {
            // Illegal instruction.
            return;
        },
    }
    self.cursor +%= 1;
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
