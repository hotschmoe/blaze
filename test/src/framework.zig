//! BLAZE Conformance Test Suite - Framework
//!
//! Core testing framework providing test suite structures, assertions,
//! and helper utilities for conformance testing.

const std = @import("std");

/// Errors that can occur during test execution.
pub const TestError = error{
    /// Test is not yet implemented.
    NotImplemented,
    /// Test assertion failed.
    AssertionFailed,
    /// Test timed out.
    Timeout,
    /// Resource allocation failed.
    OutOfMemory,
    /// GPU device error.
    DeviceError,
    /// Shader compilation error.
    ShaderCompilationFailed,
    /// Pipeline creation error.
    PipelineCreationFailed,
    /// Buffer operation error.
    BufferError,
    /// Texture operation error.
    TextureError,
    /// Synchronization error.
    SyncError,
    /// Golden image mismatch.
    GoldenMismatch,
    /// Invalid test configuration.
    InvalidConfig,
    /// Feature not supported on this device.
    FeatureNotSupported,
    /// Validation layer error.
    ValidationError,
};

/// Function pointer type for test execution.
pub const TestFn = *const fn () TestError!void;

/// Represents a single test case within a suite.
pub const TestCase = struct {
    /// Unique name for the test (e.g., "CTX-001_create_default").
    name: []const u8,
    /// Function to execute for this test.
    run: TestFn,
    /// Whether this test requires GPU (can be skipped in headless mode).
    requires_gpu: bool = true,
    /// Expected time budget in milliseconds (0 = no limit).
    timeout_ms: u32 = 5000,
    /// Test priority level.
    priority: Priority = .p0,
    /// Optional tags for filtering.
    tags: []const []const u8 = &.{},
};

/// Test priority levels as defined in CONFORMANCE.md.
pub const Priority = enum {
    /// Critical - Must pass for release.
    p0,
    /// Important - Should pass for release.
    p1,
    /// Nice to have - May be deferred.
    p2,
};

/// Represents a collection of related test cases.
pub const TestSuite = struct {
    /// Suite name (e.g., "blaze.context").
    name: []const u8,
    /// Array of test cases in this suite.
    tests: []const TestCase,
    /// Optional setup function called before each test.
    setup: ?*const fn () TestError!void = null,
    /// Optional teardown function called after each test.
    teardown: ?*const fn () void = null,
};

/// Result of a single test execution.
pub const TestResult = struct {
    name: []const u8,
    category: []const u8,
    status: Status,
    duration_ns: u64,
    message: ?[]const u8 = null,
    diff_image_path: ?[]const u8 = null,

    pub const Status = enum {
        passed,
        failed,
        skipped,
        timeout,
    };

    pub fn isPassed(self: TestResult) bool {
        return self.status == .passed;
    }
};

// ============================================================================
// Assertion Helpers
// ============================================================================

/// Asserts that the condition is true.
pub fn expect(condition: bool) TestError!void {
    if (!condition) {
        return error.AssertionFailed;
    }
}

/// Asserts that the condition is true, with a custom message on failure.
pub fn expectMsg(condition: bool, message: []const u8) TestError!void {
    _ = message; // TODO: Store message for error reporting
    if (!condition) {
        return error.AssertionFailed;
    }
}

/// Asserts that two values are equal.
pub fn expectEqual(comptime T: type, expected: T, actual: T) TestError!void {
    if (expected != actual) {
        return error.AssertionFailed;
    }
}

/// Asserts that two slices are equal.
pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) TestError!void {
    if (expected.len != actual.len) {
        return error.AssertionFailed;
    }
    for (expected, actual) |e, a| {
        if (e != a) {
            return error.AssertionFailed;
        }
    }
}

/// Asserts that two floating point values are approximately equal.
pub fn expectApproxEqual(comptime T: type, expected: T, actual: T, tolerance: T) TestError!void {
    const diff = if (expected > actual) expected - actual else actual - expected;
    if (diff > tolerance) {
        return error.AssertionFailed;
    }
}

/// Asserts that a value is within the specified range [min, max].
pub fn expectInRange(comptime T: type, value: T, min: T, max: T) TestError!void {
    if (value < min or value > max) {
        return error.AssertionFailed;
    }
}

/// Asserts that a pointer/optional is not null.
pub fn expectNotNull(value: anytype) TestError!void {
    const T = @TypeOf(value);
    const is_optional = @typeInfo(T) == .optional;
    const is_pointer = @typeInfo(T) == .pointer;

    if (is_optional) {
        if (value == null) {
            return error.AssertionFailed;
        }
    } else if (is_pointer) {
        // Pointers in Zig are never null unless they're optional
        _ = value;
    } else {
        @compileError("expectNotNull expects an optional or pointer type");
    }
}

/// Asserts that a function returns an error.
pub fn expectError(comptime expected_error: anyerror, result: anytype) TestError!void {
    if (result) |_| {
        return error.AssertionFailed;
    } else |err| {
        if (err != expected_error) {
            return error.AssertionFailed;
        }
    }
}

// ============================================================================
// Test Context Helpers
// ============================================================================

/// Global test allocator for use within tests.
pub var test_allocator: std.mem.Allocator = std.heap.page_allocator;

/// Sets the global test allocator.
pub fn setTestAllocator(allocator: std.mem.Allocator) void {
    test_allocator = allocator;
}

/// Returns the global test allocator.
pub fn getAllocator() std.mem.Allocator {
    return test_allocator;
}

// ============================================================================
// Golden Image Helpers (delegated to golden.zig)
// ============================================================================

/// Options for golden image comparison.
pub const GoldenCompareOptions = struct {
    /// Per-pixel color tolerance (0-255 per channel).
    color_tolerance: u8 = 2,
    /// Maximum percentage of pixels allowed to differ.
    max_diff_percent: f32 = 0.1,
    /// Enable perceptual comparison (LAB color space).
    perceptual: bool = true,
    /// Ignore anti-aliasing edge pixels.
    ignore_aa: bool = true,
};

/// Compares rendered output against a golden image.
/// This is a stub that will be implemented in golden.zig.
pub fn compareToGolden(
    test_name: []const u8,
    actual_data: []const u8,
    width: u32,
    height: u32,
    options: GoldenCompareOptions,
) TestError!void {
    _ = test_name;
    _ = actual_data;
    _ = width;
    _ = height;
    _ = options;
    // TODO: Delegate to golden.zig implementation
    return error.NotImplemented;
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Skips the current test with a reason.
pub fn skip(reason: []const u8) TestError!void {
    _ = reason;
    // TODO: Implement proper skip tracking
    return error.NotImplemented;
}

/// Marks a test as requiring a specific feature.
pub fn requireFeature(feature: []const u8) TestError!void {
    _ = feature;
    // TODO: Check if feature is available
    return error.NotImplemented;
}

/// Logs a message during test execution (for debugging).
pub fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[TEST] " ++ fmt ++ "\n", args);
}
