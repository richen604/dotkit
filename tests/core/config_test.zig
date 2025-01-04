const std = @import("std");
const testing = @import("std").testing;
const schema = @import("core").config.schema;
const Ymlz = @import("ymlz").Ymlz;

test "@core.config.file_mapping" {
    const mapping = schema.FileMapping.init();
    try testing.expectEqualStrings("", mapping.source);
    try testing.expectEqualStrings("", mapping.target);
    try testing.expect(!mapping.executable);

    std.debug.print("@core.config.file_mapping result: {{ source: '{s}', target: '{s}', executable: {} }}\n", .{ mapping.source, mapping.target, mapping.executable });
}

test "@core.config.module_config" {
    var config = schema.ModuleConfig.init();
    config.name = "test";
    config.namespace = "test";
    config.category = "test";
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
    var source = schema.Source.init();
    source.type = .git;
    source.url = "https://github.com/example/repo.git";
    try source.validate();

    std.debug.print("@core.config.source result: {{ type: {}, location: {?s}, url: {?s}, " ++
        "branch: {?s}, ref: {?s}, enable: {}, config: {?} }}\n", .{ source.type, source.location, source.url, source.branch, source.ref, source.enable, source.config });
}

test "@core.config.global_config" {
    var config = schema.GlobalConfig.init();
    config.name = "test";
    config.namespace = "test";

    // Create sources array without making it const
    var sources = [_]schema.Source{
        .{
            .type = .git,
            .url = "https://github.com/example/repo1.git",
            .enable = true,
        },
        .{
            .type = .git,
            .url = "https://github.com/example/repo2.git",
            .enable = true,
        },
    };

    // Create module entries array without making it const
    const module_entry = schema.GlobalConfig.ModuleEntry{
        .name = "test_module",
        .sources = &sources,
    };

    var modules = [_]schema.GlobalConfig.ModuleEntry{module_entry};
    config.modules = &modules;

    try config.validate();

    std.debug.print("@core.config.global_config result: {{ name: {?s}, namespace: '{s}', description: {?s}, " ++
        "backup_path: {?s}, hooks: {?}, modules: [{{ name: '{?s}', sources: [{{ type: {any}, url: '{?s}' }}, " ++
        "{{ type: {any}, url: '{?s}' }}] }}] }}\n", .{
        config.name,
        config.namespace,
        config.description,
        config.backup_path,
        config.hooks,
        module_entry.name,
        sources[0].type,
        sources[0].url,
        sources[1].type,
        sources[1].url,
    });
}

// TODO: sub modules inherit
