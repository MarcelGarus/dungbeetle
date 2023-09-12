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
pub fn arg(self: Self, n: u8) u8 {
    return self.memory[self.cursor + 1 + n];
}
pub fn run(self: *Self) !void {
    const instruction = try self.current_instruction();
    instruction.run(self);
}

pub fn can_run(self: *Self) bool {
    const instruction = self.current_instruction() catch {
        return false;
    };
    return instruction != .halt;
}

pub fn render_to_ui(self: Self, ui: *Ui) void {
    ui.clear();

    { // Chrome
        const style = .{ .chrome = true };
        for (0..Ui.width) |x| {
            ui.write_char(x, 0, ' ', style);
            ui.write_char(x, 17, ' ', style);
        }
        for (0..Ui.height) |y| {
            ui.write_char(0, y, ' ', style);
            ui.write_char(50, y, ' ', style);
            ui.write_char(67, y, ' ', style);
        }
        for (0..16) |i| {
            const hex_chars = "0123456789abcdef";
            ui.write_char(i * 3 + 3, 0, hex_chars[i], style);
            ui.write_char(0, i + 1, hex_chars[i], style);
        }
        ui.write_hex(47, 17, self.cursor, style);
        ui.write_text(57, 17, "dungbeetle", style);
    }

    const current_value = self.memory[self.cursor];
    for (0.., self.memory) |i, byte| {
        const color = color: {
            const instruction = self.instruction_at(@intCast(i)) catch {
                break :color null;
            };
            break :color instruction.color();
        };
        const style = .{
            .reversed = i == self.cursor,
            .underlined = i == current_value,
            .color = color,
        };

        { // Hex view
            const x = i % 16 * 3 + 2;
            const y = i / 16 + 1;
            ui.write_hex(x, y, byte, style);
        }

        { // ASCII view
            const x = i % 16 + 51;
            const y = i / 16 + 1;
            const char = switch (byte) {
                0 => ' ',
                32...126 => byte,
                else => '.',
            };
            ui.write_char(x, y, char, style);
        }
    }

    instruction_line: {
        const y = 17;
        const style = .{ .chrome = true };

        const instruction = self.current_instruction() catch {
            ui.write_text(2, y, "illegal instruction", style);
            break :instruction_line;
        };
        var name = @tagName(instruction);

        ui.write_text(2, y, name, style);
        for (0..instruction.num_args()) |i| {
            ui.write_hex(name.len + 3 * i + 3, y, self.arg(@intCast(i)), style);
        }
    }
}
