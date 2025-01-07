const std = @import("std");
const testing = @import("std").testing;
const schema = @import("core").config.schema;
const Ymlz = @import("ymlz").Ymlz;

test "@core.config.file_mapping" {
    const mapping = schema.FileMapping{};
    try testing.expectEqualStrings("", mapping.source);
    try testing.expectEqualStrings("", mapping.target);
    try testing.expect(!mapping.executable);

    std.debug.print("@core.config.file_mapping result: {{ source: '{s}', target: '{s}', executable: {} }}\n", .{ mapping.source, mapping.target, mapping.executable });
}

test "@core.config.module_config" {
    var config = schema.ModuleConfig{
        .name = "test",
        .namespace = "test",
        .category = "test",
    };
    try config.validate();

    std.debug.print("@core.config.module_config result: {{ name: '{s}', namespace: '{s}', " ++
        "category: '{s}', description: {?s}, dependencies: {?any}, config_path: {?s}, " ++
        "files: {any}, hooks: {?any} }}\n", .{
        config.name,
        config.namespace,
        config.category,
        config.description,
        config.dependencies,
        config.config_path,
        config.files,
        config.hooks,
    });
}

test "@core.config.source" {
    // Test git source inference
    var git_source = schema.Source{
        .url = "https://github.com/example/repo.git",
    };
    try testing.expectEqual(git_source.inferType(), .git);
    try git_source.validate();

    // Test path source inference
    var path_source = schema.Source{
        .location = "./local/path",
    };
    try testing.expectEqual(path_source.inferType(), .path);
    try path_source.validate();

    // Test module source inference
    const module_config = schema.ModuleConfig{
        .name = "test_module",
        .namespace = "test",
        .category = "test",
    };

    var module_source = schema.Source{
        .module = module_config,
    };
    try testing.expectEqual(module_source.inferType(), .module);
    try module_source.validate();

    std.debug.print("@core.config.source results:\n" ++
        "Git source: {{ type: {}, url: {?s} }}\n" ++
        "Path source: {{ type: {}, location: {?s} }}\n" ++
        "Module source: {{ type: {}, module: {{ name: {s} }} }}\n", .{ git_source.inferType(), git_source.url, path_source.inferType(), path_source.location, module_source.inferType(), module_source.module.?.name });
}

test "@core.config.global_config" {
    var sources = [_]schema.Source{
        .{
            .url = "https://github.com/example/repo1.git",
            .enable = true,
        },
        .{
            .url = "https://github.com/example/repo2.git",
            .enable = true,
        },
    };

    // Create a slice from the array
    const sources_slice = sources[0..];

    var module_entries = [_]schema.GlobalConfig.ModuleEntry{
        .{
            .name = "test_module",
            .sources = sources_slice,
        },
    };

    // Create a slice from the module entries array
    const modules_slice = module_entries[0..];

    var config = schema.GlobalConfig{
        .name = "test",
        .namespace = "test",
        .modules = modules_slice,
    };

    try config.validate();

    std.debug.print("@core.config.global_config result: {{ name: {?s}, namespace: '{s}', description: {?s}, " ++
        "backup_path: {?s}, hooks: {?}, modules: [{{ name: '{?s}', sources: [{{ type: {any}, url: '{?s}' }}, " ++
        "{{ type: {any}, url: '{?s}' }}] }}] }}\n", .{
        config.name,
        config.namespace,
        config.description,
        config.backup_path,
        config.hooks,
        config.modules[0].name,
        sources[0].type,
        sources[0].url,
        sources[1].type,
        sources[1].url,
    });
}
