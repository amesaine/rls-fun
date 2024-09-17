// This is a minimal pratt parser written in Dod style.
// Line 50 for the undefined assignment.
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const input: []const u8 = "1 + 2 + f . g . h * 3";
    const ast = try Ast.init(allocator, input);
    std.debug.print("{any}\n", .{ast.operands});
    // { 1, 2, 3, 2863311530, 5, 6, 7, 8, 9, 10 }
}

const Sexpr = struct {
    tag: Tag,
    ch: u8,
    operands_start: Parser.Index,

    const Tag = enum { atom, cons };
};

const Parser = struct {
    allocator: Allocator,
    tokens: []const Lexer.Token,
    tk_i: usize,
    sexprs: DynamicArray(Sexpr),
    operands: DynamicArray(Index),

    const Index = u32;

    fn parse(p: *Parser, bp_min: u8) !Index {
        const root_i = try p.sexprs_reserve();
        var root: Sexpr = undefined;

        root = switch (p.next_tk()) {
            .atom => |ch| Sexpr{ .ch = ch, .tag = .atom, .operands_start = undefined },
            else => unreachable,
        };
        while (p.peek_tk() != .eof) {
            const operator = p.peek_tk().op;
            if (BindingPower.infix(operator)) |bp| {
                if (bp.left < bp_min) break;
                _ = p.next_tk(); // eat op

                const start_i = try p.sexprs_append(root);
                const start_i_i = try p.operands_append(start_i);

                const last_i_i = try p.operands_reserve();
                // Undefined sometimes.
                p.operands.items[last_i_i] = try p.parse(bp.right);

                // This fixes it.
                // const last_i = try p.parse(bp.right);
                // p.operands.items[last_i_i] = last_i;

                root = Sexpr{ .tag = .cons, .ch = operator, .operands_start = start_i_i };
                continue;
            }
            break;
        }
        p.sexprs.items[root_i] = root;
        return root_i;
    }

    fn peek_tk(p: *Parser) Lexer.Token {
        return p.tokens[p.tk_i];
    }

    fn next_tk(p: *Parser) Lexer.Token {
        p.tk_i += 1;
        return p.tokens[p.tk_i - 1];
    }

    fn sexprs_append(p: *Parser, s: Sexpr) !Index {
        try p.sexprs.append(p.allocator, s);
        return @intCast(p.sexprs.items.len - 1);
    }

    fn sexprs_reserve(p: *Parser) !Index {
        try p.sexprs.resize(p.allocator, p.sexprs.items.len + 1);
        return @intCast(p.sexprs.items.len - 1);
    }

    fn operands_append(p: *Parser, i: Index) !Index {
        try p.operands.append(p.allocator, i);
        return @intCast(p.operands.items.len - 1);
    }

    fn operands_reserve(p: *Parser) !Index {
        try p.operands.resize(p.allocator, p.operands.items.len + 1);
        return @intCast(p.operands.items.len - 1);
    }
};

const Ast = struct {
    sexprs: []const Sexpr,
    operands: []const Parser.Index,

    fn init(allocator: Allocator, input: []const u8) !Ast {
        var lexer = Lexer{ .source = input };
        var tokens = DynamicArray(Lexer.Token){};
        defer tokens.deinit(allocator);
        while (true) {
            const token = lexer.next();
            try tokens.append(allocator, token);
            switch (token) {
                .eof => break,
                else => {},
            }
        }
        var parser = Parser{
            .allocator = allocator,
            .tokens = try tokens.toOwnedSlice(allocator),
            .tk_i = 0,
            .sexprs = .{},
            .operands = .{},
        };

        _ = try parser.parse(0);

        return Ast{
            .sexprs = try parser.sexprs.toOwnedSlice(allocator),
            .operands = try parser.operands.toOwnedSlice(allocator),
        };
    }
};

// Here's the actual tests for reference.
//     --- Only one with undefined problems. ---
//     try test_ast_stringify(
//         " 1 + 2 + f . g . h * 3 * 4",
//         "(+ (+ 1 2) (* (* (. f (. g h)) 3) 4))",
//     );
//
//     --- The rest of these pass. ---
//
//     try test_ast_stringify(
//         "1",
//         "1",
//     );
//
//     try test_ast_stringify(
//         "1 + 2 * 3",
//         "(+ 1 (* 2 3))",
//     );
//
//     try test_ast_stringify(
//         "a + b * c * d + e",
//         "(+ (+ a (* (* b c) d)) e)",
//     );
//
//     try test_ast_stringify(
//         "f . g . h",
//         "(. f (. g h))",
//     );
//
//
//     try test_ast_stringify(
//         "--1 * 2",
//         "(* (- (- 1)) 2)",
//     );
//
//     try test_ast_stringify(
//         "--f . g",
//         "(- (- (. f g)))",
//     );
//
//     try test_ast_stringify(
//         "-9!",
//         "(- (! 9))",
//     );
//
//     try test_ast_stringify(
//         "f . g !",
//         "(! (. f g))",
//     );
//
//     try test_ast_stringify(
//         "(((0)))",
//         "0",
//     );
//
//     try test_ast_stringify(
//         "x[0][1]",
//         "([ ([ x 0) 1)",
//     );
//
//     try test_ast_stringify(
//         "a ? b : c ? d : e",
//         "(? a b (? c d e))",
//     );
//
//     try test_ast_stringify(
//         "a = 0 ? b : c = d",
//         "(= a (= (? 0 b c) d))",
//     );
// }
const std = @import("std");
const Allocator = std.mem.Allocator;
const DynamicArray = std.ArrayListUnmanaged;
const Lexer = @import("lexer.zig");
const BindingPower = @import("binding_power.zig");
