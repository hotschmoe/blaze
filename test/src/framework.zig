//! BLAZE Conformance Test Suite - Framework
//!
//! Core testing framework providing test suite structures, assertions,
//! and helper utilities for conformance testing.

const std = @import("std");

pub const TestError = error{
    NotImplemented,
    AssertionFailed,
    Timeout,
    OutOfMemory,
    DeviceError,
    ShaderCompilationFailed,
    PipelineCreationFailed,
    BufferError,
    TextureError,
    SyncError,
    GoldenMismatch,
    InvalidConfig,
    FeatureNotSupported,
    ValidationError,
};

pub const TestFn = *const fn () TestError!void;

pub const TestCase = struct {
    name: []const u8,
    run: TestFn,
    requires_gpu: bool = true,
    timeout_ms: u32 = 5000,
    priority: Priority = .p0,
    tags: []const []const u8 = &.{},
};

pub const Priority = enum { p0, p1, p2 };

pub const TestSuite = struct {
    name: []const u8,
    tests: []const TestCase,
    setup: ?*const fn () TestError!void = null,
    teardown: ?*const fn () void = null,
};

pub const TestResult = struct {
    name: []const u8,
    category: []const u8,
    status: Status,
    duration_ns: u64,
    message: ?[]const u8 = null,
    diff_image_path: ?[]const u8 = null,

    pub const Status = enum { passed, failed, skipped, timeout };
};

// Assertion Helpers

pub fn expect(condition: bool) TestError!void {
    if (!condition) return error.AssertionFailed;
}

pub fn expectEqual(comptime T: type, expected: T, actual: T) TestError!void {
    if (expected != actual) return error.AssertionFailed;
}

pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) TestError!void {
    if (expected.len != actual.len) return error.AssertionFailed;
    for (expected, actual) |e, a| {
        if (e != a) return error.AssertionFailed;
    }
}

pub fn expectApproxEqual(comptime T: type, expected: T, actual: T, tolerance: T) TestError!void {
    const diff = @abs(expected - actual);
    if (diff > tolerance) return error.AssertionFailed;
}

pub fn expectInRange(comptime T: type, value: T, min: T, max: T) TestError!void {
    if (value < min or value > max) return error.AssertionFailed;
}

pub fn expectNotNull(value: anytype) TestError!void {
    const info = @typeInfo(@TypeOf(value));
    if (info == .optional) {
        if (value == null) return error.AssertionFailed;
    } else if (info != .pointer) {
        @compileError("expectNotNull expects an optional or pointer type");
    }
}

pub fn expectError(comptime expected_error: anyerror, result: anytype) TestError!void {
    if (result) |_| {
        return error.AssertionFailed;
    } else |err| {
        if (err != expected_error) return error.AssertionFailed;
    }
}

// Test Context

pub var test_allocator: std.mem.Allocator = std.heap.page_allocator;

pub fn setTestAllocator(allocator: std.mem.Allocator) void {
    test_allocator = allocator;
}

pub fn getAllocator() std.mem.Allocator {
    return test_allocator;
}

// Golden Image Comparison (see golden.zig for full implementation)

const golden = @import("golden.zig");
pub const GoldenCompareOptions = golden.ImageCompareOptions;

// Utilities

pub fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[TEST] " ++ fmt ++ "\n", args);
}
