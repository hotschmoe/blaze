//! BLAZE Conformance Test Suite - Golden Image Testing
//!
//! Utilities for golden image comparison, loading, saving, and
//! comparing rendered output against reference images.

const std = @import("std");

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
        if (slice.len > 3) slice[3] = self.a;
    }
};

pub const Image = struct {
    width: u32,
    height: u32,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Image {
        const size = @as(usize, width) * @as(usize, height) * 4;
        return .{
            .width = width,
            .height = height,
            .data = try allocator.alloc(u8, size),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    fn pixelOffset(self: Image, x: u32, y: u32) usize {
        return (@as(usize, y) * @as(usize, self.width) + @as(usize, x)) * 4;
    }

    pub fn getPixel(self: Image, x: u32, y: u32) Pixel {
        return Pixel.fromSlice(self.data[self.pixelOffset(x, y)..][0..4]);
    }

    pub fn setPixel(self: *Image, x: u32, y: u32, pixel: Pixel) void {
        pixel.toSlice(self.data[self.pixelOffset(x, y)..][0..4]);
    }
};

pub const ImageCompareOptions = struct {
    color_tolerance: u8 = 2,
    max_diff_percent: f32 = 0.1,
    perceptual: bool = true,
    ignore_aa: bool = true,
    vendor_suffix: ?[]const u8 = null,
};

pub const ImageCompareResult = struct {
    match: bool,
    diff_percent: f32,
    diff_count: u32,
    max_diff: u32,
    reason: ?MismatchReason = null,

    pub const MismatchReason = enum {
        dimension_mismatch,
        color_tolerance_exceeded,
        diff_percent_exceeded,
    };
};

pub fn compareImages(actual: Image, expected: Image, options: ImageCompareOptions) ImageCompareResult {
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

    for (0..actual.height) |y| {
        for (0..actual.width) |x| {
            const actual_pixel = actual.getPixel(@intCast(x), @intCast(y));
            const expected_pixel = expected.getPixel(@intCast(x), @intCast(y));

            const diff = if (options.perceptual)
                perceptualDiff(actual_pixel, expected_pixel)
            else
                colorDiff(actual_pixel, expected_pixel);

            if (diff > options.color_tolerance) {
                if (options.ignore_aa and isEdgePixel(expected, @intCast(x), @intCast(y))) continue;
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

fn colorDiff(a: Pixel, b: Pixel) u32 {
    return @as(u32, absDiff(a.r, b.r)) +
        @as(u32, absDiff(a.g, b.g)) +
        @as(u32, absDiff(a.b, b.b)) +
        @as(u32, absDiff(a.a, b.a));
}

fn perceptualDiff(a: Pixel, b: Pixel) u32 {
    // Simplified perceptual difference using weighted RGB
    // Human eye is more sensitive to green, less to blue
    const dr = @as(i32, a.r) - @as(i32, b.r);
    const dg = @as(i32, a.g) - @as(i32, b.g);
    const db = @as(i32, a.b) - @as(i32, b.b);

    const weighted = (dr * dr * 2 + dg * dg * 4 + db * db * 3) / 9;
    return @intFromFloat(std.math.sqrt(@as(f32, @floatFromInt(@max(0, weighted)))));
}

fn isEdgePixel(image: Image, x: u32, y: u32) bool {
    const center = image.getPixel(x, y);
    const neighbors = [_]?Pixel{
        if (x > 0) image.getPixel(x - 1, y) else null,
        if (x < image.width - 1) image.getPixel(x + 1, y) else null,
        if (y > 0) image.getPixel(x, y - 1) else null,
        if (y < image.height - 1) image.getPixel(x, y + 1) else null,
    };

    for (neighbors) |maybe_neighbor| {
        if (maybe_neighbor) |neighbor| {
            if (colorDiff(center, neighbor) > 30) return true;
        }
    }
    return false;
}

fn absDiff(a: u8, b: u8) u8 {
    return if (a > b) a - b else b - a;
}

// Image I/O (stubs for future implementation)

pub fn loadPng(allocator: std.mem.Allocator, path: []const u8) !Image {
    _ = allocator;
    _ = path;
    return error.NotImplemented;
}

pub fn savePng(image: Image, path: []const u8) !void {
    _ = image;
    _ = path;
    return error.NotImplemented;
}

pub fn generateDiffImage(allocator: std.mem.Allocator, actual: Image, expected: Image) !Image {
    if (actual.width != expected.width or actual.height != expected.height) {
        return error.InvalidArgument;
    }

    var diff = try Image.init(allocator, actual.width, actual.height);
    errdefer diff.deinit();

    for (0..actual.height) |y| {
        for (0..actual.width) |x| {
            const ax: u32 = @intCast(x);
            const ay: u32 = @intCast(y);
            const actual_pixel = actual.getPixel(ax, ay);
            const expected_pixel = expected.getPixel(ax, ay);

            if (colorDiff(actual_pixel, expected_pixel) > 2) {
                diff.setPixel(ax, ay, .{ .r = 255, .g = 0, .b = 0, .a = 255 });
            } else {
                diff.setPixel(ax, ay, .{
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

// Golden Image Management

pub const GOLDEN_DIR = "test/golden";
pub const DIFFS_DIR = "test/diffs";

pub fn getGoldenPath(allocator: std.mem.Allocator, category: []const u8, test_name: []const u8, vendor_suffix: ?[]const u8) ![]u8 {
    return if (vendor_suffix) |suffix|
        std.fmt.allocPrint(allocator, "{s}/{s}/{s}_{s}.png", .{ GOLDEN_DIR, category, test_name, suffix })
    else
        std.fmt.allocPrint(allocator, "{s}/{s}/{s}.png", .{ GOLDEN_DIR, category, test_name });
}

pub fn getDiffPath(allocator: std.mem.Allocator, category: []const u8, test_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}_{s}_diff.png", .{ DIFFS_DIR, category, test_name });
}

pub const GoldenError = error{
    NotImplemented,
    InvalidArgument,
    FileNotFound,
    ImageLoadFailed,
    ImageSaveFailed,
    ComparisonFailed,
};

pub fn verifyAgainstGolden(
    allocator: std.mem.Allocator,
    actual: Image,
    category: []const u8,
    test_name: []const u8,
    options: ImageCompareOptions,
    save_diff: bool,
) (GoldenError || std.mem.Allocator.Error)!ImageCompareResult {
    _ = .{ allocator, actual, category, test_name, options, save_diff };
    return error.NotImplemented;
}

pub fn updateGolden(allocator: std.mem.Allocator, actual: Image, category: []const u8, test_name: []const u8, vendor_suffix: ?[]const u8) !void {
    const path = try getGoldenPath(allocator, category, test_name, vendor_suffix);
    defer allocator.free(path);
    try savePng(actual, path);
}
