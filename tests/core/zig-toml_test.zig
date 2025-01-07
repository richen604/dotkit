const std = @import("std");
const testing = std.testing;
const toml = @import("toml");

test "minimal toml parsing" {
    const toml_content =
        \\first = 500
        \\name = "test"
    ;

    const Test = struct {
        first: i64,
        name: []const u8,
    };

    var parser = toml.Parser(Test).init(testing.allocator);
    defer parser.deinit();

    const result = try parser.parseString(toml_content);
    defer result.deinit();

    try testing.expectEqual(@as(i64, 500), result.value.first);
    try testing.expectEqualStrings("test", result.value.name);
}

test "complex toml structure" {
    const toml_content =
        \\first = 500
        \\second = -3
        \\name = "just testing strings overhere"
        \\fourth = 142.241
        \\
        \\foods = ["Apple", "Orange", "Strawberry", "Mango"]
        \\
        \\[inner]
        \\abcd = 12
        \\k = 2
        \\l = "hello world"
        \\
        \\[inner.another]
        \\new = 1
        \\stringed = "its just a string"
    ;

    // Define a struct that matches the TOML structure
    const Inner = struct {
        abcd: i64,
        k: i64,
        l: []const u8,
        another: struct {
            new: f64,
            stringed: []const u8,
        },
    };

    const Config = struct {
        first: i64,
        second: i64,
        name: []const u8,
        fourth: f64,
        foods: []const []const u8,
        inner: Inner,
    };

    var parser = toml.Parser(Config).init(testing.allocator);
    defer parser.deinit();

    const result = try parser.parseString(toml_content);
    defer result.deinit();

    try testing.expectEqual(@as(i64, 500), result.value.first);
    try testing.expectEqual(@as(i64, -3), result.value.second);
    try testing.expectEqualStrings("just testing strings overhere", result.value.name);
    try testing.expectApproxEqAbs(@as(f64, 142.241), result.value.fourth, 0.001);

    // Test array
    try testing.expectEqualStrings("Apple", result.value.foods[0]);
    try testing.expectEqualStrings("Orange", result.value.foods[1]);
    try testing.expectEqualStrings("Strawberry", result.value.foods[2]);
    try testing.expectEqualStrings("Mango", result.value.foods[3]);

    // Test nested tables
    try testing.expectEqual(@as(i64, 12), result.value.inner.abcd);
    try testing.expectEqual(@as(i64, 2), result.value.inner.k);
    try testing.expectEqualStrings("hello world", result.value.inner.l);

    try testing.expectApproxEqAbs(@as(f64, 1), result.value.inner.another.new, 0.001);
    try testing.expectEqualStrings("its just a string", result.value.inner.another.stringed);
}

test "optional fields" {
    const toml_content =
        \\first = 500
    ;

    const WithOptional = struct {
        first: i64,
        second: ?i64 = null,
    };

    var parser = toml.Parser(WithOptional).init(testing.allocator);
    defer parser.deinit();

    const result = try parser.parseString(toml_content);
    defer result.deinit();

    try testing.expectEqual(@as(i64, 500), result.value.first);
    try testing.expectEqual(@as(?i64, null), result.value.second);
}

test "table parsing" {
    const toml_content =
        \\[table1]
        \\a.val = 3
        \\b.val = "str1"
        \\
        \\[table2]
        \\a.val = 4
        \\b.val = "str2"
    ;

    const Table = toml.Table;

    const Tables = struct {
        table1: Table,
        table2: Table,
    };

    var parser = toml.Parser(Tables).init(testing.allocator);
    defer parser.deinit();

    const result = try parser.parseString(toml_content);
    defer result.deinit();

    try testing.expectEqual(@as(i64, 3), result.value.table1.get("a").?.table.get("val").?.integer);
    try testing.expectEqualStrings("str1", result.value.table1.get("b").?.table.get("val").?.string);
    try testing.expectEqual(@as(i64, 4), result.value.table2.get("a").?.table.get("val").?.integer);
    try testing.expectEqualStrings("str2", result.value.table2.get("b").?.table.get("val").?.string);
}

test "optional struct fields" {
    const toml_content =
        \\[sub]
        \\id = 12
        \\name = "world"
    ;

    const Sub = struct {
        id: u16,
        name: []const u8,
    };

    const Config = struct {
        sub: ?Sub,
    };

    var parser = toml.Parser(Config).init(testing.allocator);
    defer parser.deinit();

    const result = try parser.parseString(toml_content);
    defer result.deinit();

    try testing.expect(result.value.sub != null);
    try testing.expectEqual(@as(u16, 12), result.value.sub.?.id);
    try testing.expectEqualStrings("world", result.value.sub.?.name);
}
