const std = @import("std");
const testing = std.testing;
const config = @import("core").config;
const Ymlz = @import("ymlz").Ymlz;

test "@core.ymlz.minimal" {
    const yaml_content =
        \\first: 500
        \\name: test
    ;

    const Simple = struct {
        first: i32,
        name: []const u8,
    };

    var ymlz = try Ymlz(Simple).init(testing.allocator);
    const result = try ymlz.loadRaw(yaml_content);
    defer ymlz.deinit(result);

    try testing.expectEqual(@as(i32, 500), result.first);
    try testing.expectEqualStrings("test", result.name);

    std.debug.print("@core.ymlz.minimal result: {{ first: {}, name: '{s}' }}\n", .{ result.first, result.name });
}

test "@core.ymlz.complex" {
    const yaml_content =
        \\first: 500
        \\second: -3
        \\name: just testing strings overhere # just a comment
        \\fourth: 142.241
        \\# comment in between lines
        \\foods:
        \\  - Apple
        \\  - Orange
        \\  - Strawberry
        \\  - Mango
        \\inner:
        \\  abcd: 12
        \\  k: 2
        \\  l: hello world                 # comment somewhere
        \\  another:
        \\    new: 1
        \\    stringed: its just a string
    ;

    const Experiment = struct {
        first: i32,
        second: i64,
        name: []const u8,
        fourth: f32,
        foods: [][]const u8,
        inner: struct {
            abcd: i32,
            k: u8,
            l: []const u8,
            another: struct {
                new: f32,
                stringed: []const u8,
            },
        },
    };

    var ymlz = try Ymlz(Experiment).init(testing.allocator);
    const result = try ymlz.loadRaw(yaml_content);
    defer ymlz.deinit(result);

    // Add assertions to verify the parsed data
    try testing.expectEqual(@as(i32, 500), result.first);
    try testing.expectEqual(@as(i64, -3), result.second);
    try testing.expectEqualStrings("just testing strings overhere", result.name);
    try testing.expectApproxEqAbs(@as(f32, 142.241), result.fourth, 0.001);

    try testing.expectEqualStrings("Apple", result.foods[0]);
    try testing.expectEqualStrings("Orange", result.foods[1]);
    try testing.expectEqualStrings("Strawberry", result.foods[2]);
    try testing.expectEqualStrings("Mango", result.foods[3]);

    try testing.expectEqual(@as(i32, 12), result.inner.abcd);
    try testing.expectEqual(@as(u8, 2), result.inner.k);
    try testing.expectEqualStrings("hello world", result.inner.l);
    try testing.expectApproxEqAbs(@as(f32, 1), result.inner.another.new, 0.001);
    try testing.expectEqualStrings("its just a string", result.inner.another.stringed);

    std.debug.print("@core.ymlz.complex result: {{ first: {}, second: {}, name: '{s}', fourth: {}, " ++
        "foods: [{s}, {s}, {s}, {s}], " ++
        "inner: {{ abcd: {}, k: {}, l: '{s}', another: {{ new: {}, stringed: '{s}' }} }}\n", .{
        result.first,
        result.second,
        result.name,
        result.fourth,
        result.foods[0],
        result.foods[1],
        result.foods[2],
        result.foods[3],
        result.inner.abcd,
        result.inner.k,
        result.inner.l,
        result.inner.another.new,
        result.inner.another.stringed,
    });
}

test "@core.ymlz.error_handling" {
    const invalid_yaml =
        \\first: [invalid
        \\second: *
    ;

    const Simple = struct {
        first: i32,
        second: i32,
    };

    var ymlz = try Ymlz(Simple).init(testing.allocator);
    defer ymlz.deinit(null);
    try testing.expectError(error.InvalidCharacter, ymlz.loadRaw(invalid_yaml));

    std.debug.print("@core.ymlz.error_handling test: {}\n", .{error.InvalidCharacter});
}

test "@core.ymlz.optional_fields" {
    const yaml_content =
        \\first: 500
        // second is intentionally missing
    ;

    const WithOptional = struct {
        first: i32,
        second: ?i32 = null,
    };

    var ymlz = try Ymlz(WithOptional).init(testing.allocator);
    const result = try ymlz.loadRaw(yaml_content);
    defer ymlz.deinit(result);

    try testing.expectEqual(@as(i32, 500), result.first);
    try testing.expectEqual(@as(?i32, null), result.second);

    std.debug.print("@core.ymlz.optional_fields result: {{ first: {}, second: {?} }}\n", .{ result.first, result.second });
}

test "@core.ymlz.invalid_structure" {
    const invalid_yaml =
        \\first: *invalid
        \\second: 2
    ;

    const Simple = struct {
        first: i32,
        second: i32,
    };

    var ymlz = try Ymlz(Simple).init(testing.allocator);
    defer ymlz.deinit(null);
    try testing.expectError(error.InvalidCharacter, ymlz.loadRaw(invalid_yaml));

    std.debug.print("@core.ymlz.invalid_structure test: {}\n", .{error.InvalidCharacter});
}
