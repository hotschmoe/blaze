//! BLAZE Conformance Test Suite - Build Configuration
//!
//! Usage:
//!   zig build test-cts              # Run all conformance tests
//!   zig build test-cts -- --filter context  # Run only context tests
//!   zig build test-cts -- --generate-golden # Generate golden images

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const blaze_dep = b.dependency("blaze", .{
        .target = target,
        .optimize = optimize,
    });
    const blaze_mod = blaze_dep.module("blaze");

    const cts_exe = b.addExecutable(.{
        .name = "blaze-cts",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/runner.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "blaze", .module = blaze_mod },
            },
        }),
    });

    b.installArtifact(cts_exe);

    const run_cmd = b.addRunArtifact(cts_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("test-cts", "Run the BLAZE Conformance Test Suite");
    run_step.dependOn(&run_cmd.step);

    const golden_step = b.step("generate-golden", "Generate/update golden reference images");
    const golden_cmd = b.addRunArtifact(cts_exe);
    golden_cmd.addArg("--generate-golden");
    golden_step.dependOn(&golden_cmd.step);

    const framework_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/framework.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_framework_tests = b.addRunArtifact(framework_tests);

    const test_step = b.step("test", "Run unit tests for the test framework");
    test_step.dependOn(&run_framework_tests.step);
}
