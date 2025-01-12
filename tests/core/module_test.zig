const std = @import("std");
const testing = std.testing;
const schema = @import("core").config.schema;
const ModuleManager = @import("core").module.manager.ModuleManager;
const helpers = @import("helpers");

test "module manager tests" {
    const allocator = testing.allocator;
    var suite = helpers.TestSuite.init(allocator, "ModuleManager");
    defer suite.deinit();

    try suite.runTest("basic operations", struct {
        fn run() !void {
            var manager = ModuleManager.init(testing.allocator);
            defer manager.deinit();

            // Create test module config
            const config = schema.ModuleConfig{
                .name = "test-module",
                .namespace = "test",
                .category = "testing",
                .description = "Test module",
                .files = &[_]schema.FileMapping{}, // Initialize empty files array
            };

            // Load module
            try manager.loadModule(config);

            // Enable module
            try manager.enableModule("test", "test-module");

            // Verify module state
            if (try manager.getModule("test", "test-module")) |module| {
                try testing.expectEqual(module.state, .enabled);
            } else {
                return error.TestUnexpectedNull;
            }

            // Disable module
            try manager.disableModule("test", "test-module");

            // Verify disabled state
            if (try manager.getModule("test", "test-module")) |module| {
                try testing.expectEqual(module.state, .disabled);
            } else {
                return error.TestUnexpectedNull;
            }

            // List modules
            var modules = try manager.listModules();
            defer {
                for (modules.items) |*module| {
                    module.deinit(testing.allocator);
                }
                modules.deinit();
            }
            try testing.expectEqual(modules.items.len, 1);
        }
    }.run);

    // Print test results
    suite.printResults();
}
