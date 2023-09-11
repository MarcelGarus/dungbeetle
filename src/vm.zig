const std = @import("std");
const zbox = @import("zbox");
const Ui = @import("ui.zig");
const Instruction = @import("instruction.zig").Instruction;

memory: [256]u8,
cursor: u8 = 0, // Instruction pointer.

const Self = @This();

pub fn move_up(self: *Self) void {
    self.cursor -%= 16;
}
pub fn move_down(self: *Self) void {
    self.cursor +%= 16;
}
pub fn move_left(self: *Self) void {
    self.cursor -%= 1;
}
pub fn move_right(self: *Self) void {
    self.cursor +%= 1;
}
pub fn inc(self: *Self) void {
    self.memory[self.cursor] +%= 1;
}
pub fn dec(self: *Self) void {
    self.memory[self.cursor] -%= 1;
}
pub fn input(self: *Self, char: u8) void {
    self.memory[self.cursor] = char;
    self.move_right();
    return;
}
pub fn backspace(self: *Self) void {
    self.move_left();
    self.memory[self.cursor] = 0;
}

pub fn instruction_at(self: Self, pos: u8) !Instruction {
    return Instruction.parse(self.memory[pos]);
}
pub fn current_instruction(self: Self) !Instruction {
    return self.instruction_at(self.cursor);
}

// Returns the value of the nth argument of the current instruction.
pub fn arg(self: Self, comptime n: u8) u8 {
    return self.memory[self.cursor + 1 + n];
}
pub fn run(self: *Self) !void {
    const instruction = try self.current_instruction();
    instruction.run(self);
}

// Stuff for displaying the VM.

pub fn dump_to_ui(self: Self, ui: *Ui) void {
    ui.clear();

    for (0.., self.memory) |i, byte| {
        const color = color: {
            const instruction = self.instruction_at(@intCast(i)) catch {
                break :color null;
            };
            break :color instruction.color();
        };
        const style = .{
            .reversed = i == self.cursor,
            .color = color,
        };

        { // Hex view.
            const x = i % 16 * 3 + 1;
            const y = i / 16;
            ui.write_hex(x, y, byte, style);
        }

        { // ASCII view.
            const x = i % 16 + 50;
            const y = i / 16;
            const char = switch (byte) {
                32...126 => byte,
                else => '.',
            };
            ui.write_char(x, y, char, style);
        }
    }

    info_line: {
        const y = 16;
        const style = .{ .reversed = true };
        for (0..Ui.width) |x| {
            ui.write_char(x, y, ' ', style);
        }

        const instruction = self.current_instruction() catch {
            ui.write_text(1, y, "illegal instruction", style);
            break :info_line;
        };
        switch (instruction) {
            .noop => ui.write_text(1, y, "noop", style),
            .halt => ui.write_text(1, y, "halt", style),
            .move => |args| {
                _ = args;
                ui.write_text(1, y, "move", style);
                ui.write_hex(6, y, self.arg(0), style);
                ui.write_hex(9, y, self.arg(1), style);
            },
            .increment => {
                ui.write_text(1, y, "increment", style);
                ui.write_hex(10, y, self.arg(0), style);
            },
            .decrement => {
                ui.write_text(1, y, "decrement", style);
                ui.write_hex(10, y, self.arg(0), style);
            },
            .jump => {
                ui.write_text(1, y, "jump", style);
                ui.write_hex(6, y, self.arg(0), style);
            },
            .jump_if_zero => {
                ui.write_text(1, y, "jump if zero", style);
                ui.write_hex(14, y, self.arg(0), style);
                ui.write_hex(17, y, self.arg(1), style);
            },
            .jump_if_not_zero => {
                ui.write_text(1, y, "jump if not zero", style);
                ui.write_hex(18, y, self.arg(0), style);
                ui.write_hex(21, y, self.arg(1), style);
            },
            .add => {
                ui.write_text(1, y, "add", style);
                ui.write_hex(5, y, self.arg(0), style);
                ui.write_hex(8, y, self.arg(1), style);
                ui.write_hex(11, y, self.arg(2), style);
            },
        }
    }
}
