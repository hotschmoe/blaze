//! BLAZE Conformance Test Suite - Context Tests
//!
//! Tests for context creation, device selection, and lifecycle management.
//! Reference: CONFORMANCE.md Category 1: Context & Device

const std = @import("std");
const framework = @import("../framework.zig");
const blaze = @import("blaze");

pub const suite = framework.TestSuite{
    .name = "blaze.context",
    .tests = &.{
        // P0 - Critical
        .{ .name = "CTX-001_create_default", .run = createDefault, .priority = .p0 },
        .{ .name = "CTX-002_create_with_validation", .run = createWithValidation, .priority = .p0 },
        .{ .name = "CTX-003_create_compute_only", .run = createComputeOnly, .priority = .p0 },

        // P1 - Important
        .{ .name = "CTX-004_create_with_features", .run = createWithFeatures, .priority = .p1 },
        .{ .name = "CTX-005_create_preferred_device", .run = createPreferredDevice, .priority = .p1 },
        .{ .name = "CTX-006_create_missing_features", .run = createMissingFeatures, .priority = .p1 },
        .{ .name = "CTX-007_destroy_with_pending_work", .run = destroyWithPendingWork, .priority = .p1 },
        .{ .name = "CTX-009_context_device_info", .run = contextDeviceInfo, .priority = .p1 },

        // P2 - Nice to have
        .{ .name = "CTX-008_multiple_contexts", .run = multipleContexts, .priority = .p2 },
        .{ .name = "CTX-010_context_memory_budget", .run = contextMemoryBudget, .priority = .p2 },
    },
};

/// CTX-001: Create context with default configuration.
/// Verifies that a context can be created with minimal/default settings.
fn createDefault() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-002: Create context with validation layers enabled.
/// Verifies that validation layers can be enabled for debugging.
fn createWithValidation() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-003: Create headless compute-only context.
/// Verifies that a context can be created without presentation support.
fn createComputeOnly() framework.TestError!void {
    var ctx = blaze.Context.init(framework.getAllocator(), .{
        .app_name = "CTS-CTX-003",
        .validation = false,
        .mode = .compute_only,
    }) catch |err| {
        framework.log("Context creation failed: {s}", .{@errorName(err)});
        return error.DeviceError;
    };
    defer ctx.deinit();

    const name = ctx.getDeviceName();
    try framework.expect(name.len > 0);

    framework.log("Created compute-only context on: {s}", .{name});
}

/// CTX-004: Create context with specific Vulkan features requested.
fn createWithFeatures() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-005: Select GPU by name substring.
fn createPreferredDevice() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-006: Request unavailable features.
fn createMissingFeatures() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-007: Destroy context while GPU is busy.
fn destroyWithPendingWork() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-008: Create multiple contexts simultaneously.
fn multipleContexts() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-009: Query device information.
fn contextDeviceInfo() framework.TestError!void {
    return error.NotImplemented;
}

/// CTX-010: Query available VRAM.
fn contextMemoryBudget() framework.TestError!void {
    return error.NotImplemented;
}
