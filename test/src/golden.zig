//! BLAZE Conformance Test Suite - Golden Image Testing
//!
//! Provides utilities for golden image comparison, including loading,
//! saving, and comparing rendered output against reference images.

const std = @import("std");
const framework = @import("framework.zig");

/// RGBA pixel format for image data.
pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn fromSlice(slice: []const u8) Pixel {
        return .{
            .r = slice[0],
            .g = slice[1],
            .b = slice[2],
            .a = if (slice.len > 3) slice[3] else 255,
        };
    }

    pub fn toSlice(self: Pixel, slice: []u8) void {
        slice[0] = self.r;
        slice[1] = self.g;
        slice[2] = self.b;
        if (slice.len > 3) {
            slice[3] = self.a;
        }
    }
};

/// Image data container.
pub const Image = struct {
    width: u32,
    height: u32,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        const size = @as(usize, width) * @as(usize, height) * 4;
        const data = try allocator.alloc(u8, size);
        return .{
            .width = width,
            .height = height,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    pub fn getPixel(self: Image, x: u32, y: u32) Pixel {
        const offset = (@as(usize, y) * @as(usize, self.width) + @as(usize, x)) * 4;
        return Pixel.fromSlice(self.data[offset..][0..4]);
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, pixel: Pixel) void {
        const offset = (@as(usize, y) * @as(usize, self.width) + @as(usize, x)) * 4;
        pixel.toSlice(self.data[offset..][0..4]);
    }
};

/// Options for image comparison.
pub const ImageCompareOptions = struct {
    /// Per-pixel color tolerance (0-255 per channel).
    color_tolerance: u8 = 2,

    /// Maximum percentage of pixels allowed to differ.
    max_diff_percent: f32 = 0.1,

    /// Enable perceptual comparison (LAB color space).
    perceptual: bool = true,

    /// Ignore anti-aliasing edge pixels.
    ignore_aa: bool = true,

    /// Vendor-specific golden image suffix (e.g., "nvidia", "amd").
    vendor_suffix: ?[]const u8 = null,
};

/// Result of image comparison.
pub const ImageCompareResult = struct {
    /// Whether the images match within tolerance.
    match: bool,
    /// Percentage of differing pixels.
    diff_percent: f32,
    /// Total number of differing pixels.
    diff_count: u32,
    /// Maximum color difference found.
    max_diff: u32,
    /// Reason for mismatch (if any).
    reason: ?MismatchReason = null,

    pub const MismatchReason = enum {
        dimension_mismatch,
        color_tolerance_exceeded,
        diff_percent_exceeded,
    };

    pub fn isMatch(self: ImageCompareResult) bool {
        return self.match;
    }
};

/// Compares two images and returns the comparison result.
pub fn compareImages(
    actual: Image,
    expected: Image,
    options: ImageCompareOptions,
) ImageCompareResult {
    // Check dimensions first
    if (actual.width != expected.width or actual.height != expected.height) {
        return .{
            .match = false,
            .diff_percent = 100.0,
            .diff_count = actual.width * actual.height,
            .max_diff = 255 * 4,
            .reason = .dimension_mismatch,
        };
    }

    var diff_count: u32 = 0;
    var max_diff: u32 = 0;

    var y: u32 = 0;
    while (y < actual.height) : (y += 1) {
        var x: u32 = 0;
        while (x < actual.width) : (x += 1) {
            const actual_pixel = actual.getPixel(x, y);
            const expected_pixel = expected.getPixel(x, y);

            const diff = if (options.perceptual)
                perceptualDiff(actual_pixel, expected_pixel)
            else
                colorDiff(actual_pixel, expected_pixel);

            if (diff > options.color_tolerance) {
                if (options.ignore_aa and isEdgePixel(expected, x, y)) {
                    continue;
                }
                diff_count += 1;
                max_diff = @max(max_diff, diff);
            }
        }
    }

    const total_pixels = actual.width * actual.height;
    const diff_percent = if (total_pixels > 0)
        @as(f32, @floatFromInt(diff_count)) / @as(f32, @floatFromInt(total_pixels)) * 100.0
    else
        0.0;

    const match = diff_percent <= options.max_diff_percent;

    return .{
        .match = match,
        .diff_percent = diff_percent,
        .diff_count = diff_count,
        .max_diff = max_diff,
        .reason = if (!match) .diff_percent_exceeded else null,
    };
}

/// Calculates simple color difference between two pixels.
fn colorDiff(a: Pixel, b: Pixel) u32 {
    const dr = absDiff(a.r, b.r);
    const dg = absDiff(a.g, b.g);
    const db = absDiff(a.b, b.b);
    const da = absDiff(a.a, b.a);
    return @as(u32, dr) + @as(u32, dg) + @as(u32, db) + @as(u32, da);
}

/// Calculates perceptual color difference (simplified LAB approximation).
fn perceptualDiff(a: Pixel, b: Pixel) u32 {
    // Simplified perceptual difference using weighted RGB
    // Human eye is more sensitive to green, less to blue
    const dr = @as(i32, a.r) - @as(i32, b.r);
    const dg = @as(i32, a.g) - @as(i32, b.g);
    const db = @as(i32, a.b) - @as(i32, b.b);

    // Weighted sum approximating perceptual difference
    const weighted = (dr * dr * 2 + dg * dg * 4 + db * db * 3) / 9;
    const sqrt_val = std.math.sqrt(@as(f32, @floatFromInt(@max(0, weighted))));
    return @intFromFloat(sqrt_val);
}

/// Checks if a pixel is on an edge (for anti-aliasing detection).
fn isEdgePixel(image: Image, x: u32, y: u32) bool {
    const center = image.getPixel(x, y);

    // Check 4-connected neighbors
    const neighbors = [_]?Pixel{
        if (x > 0) image.getPixel(x - 1, y) else null,
        if (x < image.width - 1) image.getPixel(x + 1, y) else null,
        if (y > 0) image.getPixel(x, y - 1) else null,
        if (y < image.height - 1) image.getPixel(x, y + 1) else null,
    };

    // If any neighbor differs significantly, it's an edge
    for (neighbors) |maybe_neighbor| {
        if (maybe_neighbor) |neighbor| {
            if (colorDiff(center, neighbor) > 30) {
                return true;
            }
        }
    }

    return false;
}

/// Helper function for absolute difference.
fn absDiff(a: u8, b: u8) u8 {
    return if (a > b) a - b else b - a;
}

// ============================================================================
// Image I/O (Stubs)
// ============================================================================

/// Loads an image from a PNG file.
pub fn loadPng(allocator: std.mem.Allocator, path: []const u8) !Image {
    _ = allocator;
    _ = path;
    // TODO: Implement PNG loading (using stb_image or similar)
    return error.NotImplemented;
}

/// Saves an image to a PNG file.
pub fn savePng(image: Image, path: []const u8) !void {
    _ = image;
    _ = path;
    // TODO: Implement PNG saving (using stb_image_write or similar)
    return error.NotImplemented;
}

/// Generates a diff image highlighting differences between two images.
pub fn generateDiffImage(
    allocator: std.mem.Allocator,
    actual: Image,
    expected: Image,
) !Image {
    if (actual.width != expected.width or actual.height != expected.height) {
        return error.InvalidArgument;
    }

    var diff = try Image.init(allocator, actual.width, actual.height);
    errdefer diff.deinit();

    var y: u32 = 0;
    while (y < actual.height) : (y += 1) {
        var x: u32 = 0;
        while (x < actual.width) : (x += 1) {
            const actual_pixel = actual.getPixel(x, y);
            const expected_pixel = expected.getPixel(x, y);
            const pixel_diff = colorDiff(actual_pixel, expected_pixel);

            if (pixel_diff > 2) {
                // Highlight differences in red
                diff.setPixel(x, y, .{ .r = 255, .g = 0, .b = 0, .a = 255 });
            } else {
                // Show original with reduced opacity
                diff.setPixel(x, y, .{
                    .r = actual_pixel.r / 2,
                    .g = actual_pixel.g / 2,
                    .b = actual_pixel.b / 2,
                    .a = 128,
                });
            }
        }
    }

    return diff;
}

// ============================================================================
// Golden Image Management
// ============================================================================

/// Default path for golden images.
pub const GOLDEN_DIR = "test/golden";

/// Default path for diff images.
pub const DIFFS_DIR = "test/diffs";

/// Gets the path for a golden image.
pub fn getGoldenPath(
    allocator: std.mem.Allocator,
    category: []const u8,
    test_name: []const u8,
    vendor_suffix: ?[]const u8,
) ![]u8 {
    if (vendor_suffix) |suffix| {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}_{s}.png", .{
            GOLDEN_DIR, category, test_name, suffix,
        });
    } else {
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}.png", .{
            GOLDEN_DIR, category, test_name,
        });
    }
}

/// Gets the path for a diff image.
pub fn getDiffPath(
    allocator: std.mem.Allocator,
    category: []const u8,
    test_name: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}_{s}_diff.png", .{
        DIFFS_DIR, category, test_name,
    });
}

/// Error type for golden image operations.
pub const GoldenError = error{
    NotImplemented,
    InvalidArgument,
    FileNotFound,
    ImageLoadFailed,
    ImageSaveFailed,
    ComparisonFailed,
};

const Error = GoldenError || std.mem.Allocator.Error;

/// Compares actual output to golden image and optionally saves diff.
pub fn verifyAgainstGolden(
    allocator: std.mem.Allocator,
    actual: Image,
    category: []const u8,
    test_name: []const u8,
    options: ImageCompareOptions,
    save_diff: bool,
) Error!ImageCompareResult {
    _ = allocator;
    _ = actual;
    _ = category;
    _ = test_name;
    _ = options;
    _ = save_diff;
    // TODO: Implement full golden image verification
    return error.NotImplemented;
}

/// Saves current output as the new golden image.
pub fn updateGolden(
    allocator: std.mem.Allocator,
    actual: Image,
    category: []const u8,
    test_name: []const u8,
    vendor_suffix: ?[]const u8,
) !void {
    const path = try getGoldenPath(allocator, category, test_name, vendor_suffix);
    defer allocator.free(path);
    try savePng(actual, path);
}
