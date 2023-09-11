const std = @import("std");
const zbox = @import("zbox");
const Ui = @import("ui.zig");

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
    move: [2]u8, // from, to
    increment: u8,
    decrement: u8,
    jump: u8, // target
    jump_if_zero: [2]u8, // condition var, target
    jump_if_not_zero: [2]u8, // condition var, target
    add: [3]u8, // summand a, summand b, output

    const Self = @This();
    pub fn parse(a: u8, b: u8, c: u8, d: u8) !Self {
        return switch (a) {
            0 => .noop,
            1 => .halt,
            2 => Instruction{ .move = .{ b, c } },
            3 => Instruction{ .jump = b },
            4 => Instruction{ .jump_if_zero = .{ b, c } },
            5 => Instruction{ .jump_if_not_zero = .{ b, c } },
            6 => Instruction{ .add = .{ b, c, d } },
            7 => Instruction{ .increment = b },
            8 => Instruction{ .decrement = b },
            else => error.InvalidInstruction,
        };
    }

    pub fn len(self: Self) u8 {
        return switch (self) {
            .noop => 1,
            .halt => 1,
            .move => 3,
            .increment => 2,
            .decrement => 2,
            .jump => 2,
            .jump_if_zero => 3,
            .jump_if_not_zero => 3,
            .add => 3,
        };
    }

    pub fn color(self: Self) ?Ui.Color {
        return switch (self) {
            .noop => null,
            .halt => .red,
            .move => .cyan,
            .increment => .cyan,
            .decrement => .cyan,
            .jump => .yellow,
            .jump_if_zero => .yellow,
            .jump_if_not_zero => .yellow,
            .add => .green,
        };
    }
};

pub fn instruction_at(self: @This(), pos: u8) !Instruction {
    return Instruction.parse(
        self.memory[pos],
        self.memory[pos +% 1],
        self.memory[pos +% 2],
        self.memory[pos +% 3],
    );
}
pub fn current_instruction(self: @This()) !Instruction {
    return self.instruction_at(self.cursor);
}

pub fn run(self: *@This()) !void {
    const instruction = try self.current_instruction();
    switch (instruction) {
        .noop => {},
        .halt => return,
        .move => |args| self.memory[args[1]] = self.memory[args[0]],
        .increment => |arg| self.memory[arg] +%= 1,
        .decrement => |arg| self.memory[arg] -%= 1,
        .jump => |target| {
            self.cursor = target;
            return;
        },
        .jump_if_zero => |args| {
            if (self.memory[args[0]] == 0) {
                self.cursor = args[1];
                return;
            }
        },
        .jump_if_not_zero => |args| {
            if (self.memory[args[0]] != 0) {
                self.cursor = args[1];
                return;
            }
        },
        .add => |args| {
            self.memory[args[2]] = self.memory[args[0]] +% self.memory[args[1]];
        },
    }
    self.cursor +%= instruction.len();
}

// Stuff for displaying the VM.

const bytes_per_row = 16;

pub fn dump_to_ui(self: @This(), ui: *Ui) void {
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
            const x = i % bytes_per_row * 3 + 1;
            const y = i / bytes_per_row;
            ui.write_hex(x, y, byte, style);
        }

        { // ASCII view.
            const x = i % bytes_per_row + 50;
            const y = i / bytes_per_row;
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
                ui.write_text(1, y, "move", style);
                ui.write_hex(6, y, args[0], style);
                ui.write_hex(9, y, args[1], style);
            },
            .increment => |arg| {
                ui.write_text(1, y, "increment", style);
                ui.write_hex(10, y, arg, style);
            },
            .decrement => |arg| {
                ui.write_text(1, y, "decrement", style);
                ui.write_hex(10, y, arg, style);
            },
            .jump => |target| {
                ui.write_text(1, y, "jump", style);
                ui.write_hex(6, y, target, style);
            },
            .jump_if_zero => |args| {
                ui.write_text(1, y, "jump if zero", style);
                ui.write_hex(14, y, args[0], style);
                ui.write_hex(17, y, args[1], style);
            },
            .jump_if_not_zero => |args| {
                ui.write_text(1, y, "jump if not zero", style);
                ui.write_hex(18, y, args[0], style);
                ui.write_hex(21, y, args[1], style);
            },
            .add => |args| {
                ui.write_text(1, y, "add", style);
                ui.write_hex(5, y, args[0], style);
                ui.write_hex(8, y, args[1], style);
                ui.write_hex(11, y, args[2], style);
            },
        }
    }
}
