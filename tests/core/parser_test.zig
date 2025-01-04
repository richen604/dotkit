const std = @import("std");
const testing = std.testing;
const config = @import("core").config;

// TODO: fix optionals error from Ymlz

test "@core.config.parser.load_module_config" {
    // Create a temporary YAML file
    const yaml_content =
        \\name: test-module
        \\namespace: test
        \\category: testing
        \\description: A test module
        \\files:
        \\  - source: src/test
        \\    target: ~/.config/test
    ;

    // Write to temporary file
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "module.yml",
        .data = yaml_content,
    });

    // Initialize ModuleConfig with schema and set expected values
    var expected_config = config.schema.ModuleConfig.init();
    expected_config.name = "test-module";
    expected_config.namespace = "test";
    expected_config.category = "testing";

    // Test loading the config
    const module_config = try config.parser.loadModuleConfig(testing.allocator, "module.yml");

    try testing.expectEqualStrings(expected_config.name, module_config.name);
    try testing.expectEqualStrings(expected_config.namespace, module_config.namespace);
}

test "@core.config.parser.invalid_file" {
    try testing.expectError(error.FileNotFound, config.parser.loadModuleConfig(testing.allocator, "nonexistent.yml"));
}

test "@core.config.parser.load_global_config" {
    const yaml_content =
        \\namespace: test-global
        \\name: test-config
        \\description: A test global config
        \\backup_path: ~/.backup
        \\modules:
        \\  core:
        \\    - type: git
        \\      url: https://github.com/example/core.git
        \\      enable: true
    ;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(.{
        .sub_path = "global.yml",
        .data = yaml_content,
    });

    // Initialize GlobalConfig with schema
    var expected_config = config.schema.GlobalConfig.init(testing.allocator);
    defer expected_config.deinit();
    expected_config.namespace = "test-global";
    expected_config.name = "test-config";

    // Test loading the config
    var global_config = try config.parser.loadGlobalConfig(testing.allocator, "global.yml");
    defer global_config.deinit();

    try testing.expectEqualStrings(expected_config.namespace, global_config.namespace);
    if (global_config.name) |name| {
        try testing.expectEqualStrings(expected_config.name.?, name);
    } else {
        try testing.expect(false);
    }
}

test "@core.config.parser.invalid_global_file" {
    try testing.expectError(error.FileNotFound, config.parser.loadGlobalConfig(testing.allocator, "nonexistent.yml"));
}
