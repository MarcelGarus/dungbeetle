const Ui = @import("ui.zig");
const Vm = @import("vm.zig");

pub const Instruction = enum {
    noop,
    halt,
    move, // to, from
    increment, // target
    decrement, // target
    jump, // target
    jump_if_zero, // condition var, target
    jump_if_not_zero, // condition var, target
    add, // summand a (also target), summand b
    subtract, // a (also target), b
    multiply, // a (also target), b
    divide, // a (also target), b
    modulo, // a (also target), b

    const Self = @This();

    pub fn parse(byte: u8) !Self {
        const num_instructions = switch (@typeInfo(Self)) {
            .Enum => |e| e.fields.len,
            else => unreachable,
        };
        if (byte < num_instructions) {
            return @enumFromInt(byte);
        } else {
            return error.InvalidInstruction;
        }
    }

    pub fn num_args(self: Self) u8 {
        return switch (self) {
            .noop => 0,
            .halt => 0,
            .move => 2,
            .increment => 1,
            .decrement => 1,
            .jump => 1,
            .jump_if_zero => 2,
            .jump_if_not_zero => 2,
            .add => 2,
            .subtract => 2,
            .multiply => 2,
            .divide => 2,
            .modulo => 2,
        };
    }

    pub fn color(self: Self) ?Ui.Color {
        return switch (self) {
            .noop => .yellow,
            .halt => .red,
            .move => .cyan,
            .increment => .cyan,
            .decrement => .cyan,
            .jump => .magenta,
            .jump_if_zero => .magenta,
            .jump_if_not_zero => .magenta,
            .add => .green,
            .subtract => .green,
            .multiply => .green,
            .divide => .green,
            .modulo => .green,
        };
    }

    pub fn run(self: Self, vm: *Vm) void {
        switch (self) {
            .noop => {},
            .halt => return,
            .move => vm.memory[vm.arg(0)] = vm.memory[vm.arg(1)],
            .increment => vm.memory[vm.arg(0)] +%= 1,
            .decrement => vm.memory[vm.arg(0)] -%= 1,
            .jump => {
                vm.cursor = vm.arg(0);
                return;
            },
            .jump_if_zero => {
                if (vm.memory[vm.arg(0)] == 0) {
                    vm.cursor = vm.arg(1);
                    return;
                }
            },
            .jump_if_not_zero => {
                if (vm.memory[vm.arg(0)] != 0) {
                    vm.cursor = vm.arg(1);
                    return;
                }
            },
            .add => {
                vm.memory[vm.arg(0)] = vm.memory[vm.arg(0)] +% vm.memory[vm.arg(1)];
            },
            .subtract => {
                vm.memory[vm.arg(0)] = vm.memory[vm.arg(0)] -% vm.memory[vm.arg(1)];
            },
            .multiply => {
                vm.memory[vm.arg(0)] = vm.memory[vm.arg(0)] *% vm.memory[vm.arg(1)];
            },
            .divide => {
                vm.memory[vm.arg(0)] = vm.memory[vm.arg(0)] / vm.memory[vm.arg(1)];
            },
            .modulo => {
                vm.memory[vm.arg(0)] = vm.memory[vm.arg(0)] % vm.memory[vm.arg(1)];
            },
        }
        vm.cursor +%= 1 + self.num_args();
    }
};
