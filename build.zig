const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get Vulkan headers for the registry
    const vulkan_headers = b.dependency("vulkan_headers", .{});

    // Get vulkan-zig dependency and pass the registry path
    const vulkan_dep = b.dependency("vulkan", .{
        .registry = vulkan_headers.path("registry/vk.xml"),
    });
    const vulkan_mod = vulkan_dep.module("vulkan-zig");

    // Create the main blaze module (no system library - we use dynamic loading)
    const mod = b.addModule("blaze", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_mod },
        },
    });

    // Create executable for testing
    const exe = b.addExecutable(.{
        .name = "blaze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "blaze", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // SwiftShader download tool for CI/testing without GPU
    const fetch_swiftshader = b.addExecutable(.{
        .name = "fetch-swiftshader",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fetch_swiftshader.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_fetch = b.addRunArtifact(fetch_swiftshader);
    const fetch_step = b.step("fetch-swiftshader", "Download SwiftShader for software Vulkan rendering");
    fetch_step.dependOn(&run_fetch.step);
}
