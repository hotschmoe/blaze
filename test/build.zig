//! BLAZE Conformance Test Suite - Build Configuration
//!
//! Adds build steps for the conformance test suite.
//! Usage:
//!   zig build test-cts              # Run all conformance tests
//!   zig build test-cts -- --filter context  # Run only context tests
//!   zig build test-cts -- --generate-golden # Generate golden images
//!   zig build test-cts -- --save-diffs      # Save diff images on failure

const std = @import("std");

/// Adds the conformance test suite build step to the main build.
pub fn addConformanceTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "blaze-cts",
        .root_source_file = b.path("test/src/runner.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add blaze as a dependency (when the main library is available)
    // const blaze_mod = b.dependency("blaze", .{
    //     .target = target,
    //     .optimize = optimize,
    // }).module("blaze");
    // exe.root_module.addImport("blaze", blaze_mod);

    return exe;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the conformance test runner
    const cts_exe = b.addExecutable(.{
        .name = "blaze-cts",
        .root_source_file = b.path("src/runner.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the executable
    b.installArtifact(cts_exe);

    // Create the test-cts run step
    const run_cmd = b.addRunArtifact(cts_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing arguments to the runner
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create the test-cts step
    const run_step = b.step("test-cts", "Run the BLAZE Conformance Test Suite");
    run_step.dependOn(&run_cmd.step);

    // Create a step for generating golden images
    const golden_step = b.step("generate-golden", "Generate/update golden reference images");
    const golden_cmd = b.addRunArtifact(cts_exe);
    golden_cmd.addArg("--generate-golden");
    golden_step.dependOn(&golden_cmd.step);

    // Unit tests for the framework itself
    const framework_tests = b.addTest(.{
        .root_source_file = b.path("src/framework.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_framework_tests = b.addRunArtifact(framework_tests);

    const test_step = b.step("test", "Run unit tests for the test framework");
    test_step.dependOn(&run_framework_tests.step);
}
