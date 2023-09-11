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
    jump: u8, // target
    add: [3]u8, // two summands, output

    const Self = @This();
    pub fn parse(a: u8, b: u8, c: u8, d: u8) !Self {
        return switch (a) {
            0 => .noop,
            1 => .halt,
            2 => Instruction{ .jump = b },
            3 => Instruction{ .add = .{ b, c, d } },
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

    pub fn color(self: Self) ?Ui.Color {
        return switch (self) {
            .noop => null,
            .halt => .red,
            .jump => .yellow,
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
    const hex_chars = "0123456789abcdef";

    for (0.., self.memory) |i, byte| {
        const is_cursor = i == self.cursor;
        const style = .{
            .reverse = is_cursor,
            .fg_red = byte == 1,
            .fg_yellow = byte == 2,
            .fg_green = byte == 3,
            .fg_blue = byte == 4,
            .fg_magenta = byte == 5,
            .fg_cyan = byte == 6,
        };

        { // Hex view.
            const x = i % bytes_per_row * 3 + 1;
            const y = i / bytes_per_row;

            buffer.cellRef(y, x).* = .{
                .char = hex_chars[byte / 16],
                .attribs = style,
            };
            buffer.cellRef(y, x + 1).* = .{
                .char = hex_chars[byte % 16],
                .attribs = style,
            };
        }

        { // ASCII view.
            const x = i % bytes_per_row + 50;
            const y = i / bytes_per_row;

            const char = switch (byte) {
                32...126 => byte,
                else => '.',
            };
            buffer.cellRef(y, x).* = .{ .char = char, .attribs = style };
        }
    }

    const instruction = self.current_instruction();
    if (instruction) |instr| {
        var info: [100]u8 = undefined;
        for (0..100) |i| {
            info[i] = 0x20; // space
        }
        switch (instr) {
            .noop => @memcpy(info[0..4], "noop"),
            .halt => @memcpy(info[0..4], "halt"),
            .jump => |target| {
                @memcpy(info[0..4], "jump");
                info[6] = hex_chars[target / 16];
                info[7] = hex_chars[target % 16];
            },
            .add => |args| {
                @memcpy(info[0..3], "add");
                info[6] = hex_chars[args[0] / 16];
                info[7] = hex_chars[args[0] % 16];
                info[8] = hex_chars[args[1] / 16];
                info[9] = hex_chars[args[1] % 16];
                info[10] = hex_chars[args[2] / 16];
                info[11] = hex_chars[args[2] % 16];

                // add_info(buffer, std.fmt.format("add {} {} {}", args[0], args[1], args[2]))
            },
        }
        add_info(buffer, &info);
    } else |err| {
        err catch {};
        add_info(buffer, "Illegal instruction.");
    }
}

fn add_info(buffer: *zbox.Buffer, info: []const u8) void {
    for (0.., info) |x, char| {
        buffer.cellRef(18, x).* = .{ .char = char };
    }
}

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
            .jump => |target| {
                ui.write_text(1, y, "jump", style);
                ui.write_hex(6, y, target, style);
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
