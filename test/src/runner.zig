//! BLAZE Conformance Test Suite - Test Runner
//!
//! Main entry point for running conformance tests. Supports filtering,
//! golden image generation, and various output formats.

const std = @import("std");
const framework = @import("framework.zig");
const golden = @import("golden.zig");

// Import all test suites
const context_tests = @import("context/tests.zig");
const buffer_tests = @import("buffer/tests.zig");
const texture_tests = @import("texture/tests.zig");
const sampler_tests = @import("sampler/tests.zig");
const pipeline_tests = @import("pipeline/tests.zig");
const shader_tests = @import("shader/tests.zig");
const command_tests = @import("command/tests.zig");
const sync_tests = @import("sync/tests.zig");
const compute_tests = @import("compute/tests.zig");
const render_tests = @import("render/tests.zig");

/// Configuration options for the test runner.
pub const RunnerConfig = struct {
    /// Filter string for selecting specific tests.
    filter: ?[]const u8 = null,
    /// Generate golden images instead of comparing.
    generate_golden: bool = false,
    /// Save diff images on comparison failure.
    save_diffs: bool = false,
    /// Output JUnit XML results to this path.
    junit_output: ?[]const u8 = null,
    /// Output JSON results to this path.
    json_output: ?[]const u8 = null,
    /// Only run tests of this priority or higher.
    min_priority: framework.Priority = .p2,
    /// Verbose output mode.
    verbose: bool = false,
    /// Continue running tests after failure.
    keep_going: bool = true,
    /// Number of times to run each test (for flaky test detection).
    iterations: u32 = 1,
};

/// Test runner that executes all conformance test suites.
pub const TestRunner = struct {
    allocator: std.mem.Allocator,
    config: RunnerConfig,
    results: std.ArrayList(framework.TestResult),
    start_time: i64,

    const Self = @This();

    /// All registered test suites.
    const all_suites = [_]framework.TestSuite{
        context_tests.suite,
        buffer_tests.suite,
        texture_tests.suite,
        sampler_tests.suite,
        pipeline_tests.suite,
        shader_tests.suite,
        command_tests.suite,
        sync_tests.suite,
        compute_tests.suite,
        render_tests.suite,
    };

    pub fn init(allocator: std.mem.Allocator, config: RunnerConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .results = std.ArrayList(framework.TestResult).init(allocator),
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }

    /// Runs all test suites and returns the number of failures.
    pub fn run(self: *Self) !u32 {
        self.printHeader();

        var failures: u32 = 0;

        for (all_suites) |suite| {
            if (self.shouldSkipSuite(suite)) {
                continue;
            }

            const suite_failures = try self.runSuite(suite);
            failures += suite_failures;

            if (suite_failures > 0 and !self.config.keep_going) {
                break;
            }
        }

        self.printSummary();

        if (self.config.junit_output) |path| {
            try self.writeJunitXml(path);
        }

        if (self.config.json_output) |path| {
            try self.writeJsonOutput(path);
        }

        return failures;
    }

    fn shouldSkipSuite(self: *Self, suite: framework.TestSuite) bool {
        if (self.config.filter) |filter| {
            // Check if filter matches suite name
            if (std.mem.indexOf(u8, suite.name, filter) != null) {
                return false;
            }
            // Check if filter matches any test name
            for (suite.tests) |test_case| {
                if (std.mem.indexOf(u8, test_case.name, filter) != null) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    fn shouldSkipTest(self: *Self, suite: framework.TestSuite, test_case: framework.TestCase) bool {
        // Check priority
        if (@intFromEnum(test_case.priority) > @intFromEnum(self.config.min_priority)) {
            return true;
        }

        // Check filter
        if (self.config.filter) |filter| {
            const full_name = suite.name ++ "." ++ test_case.name;
            if (std.mem.indexOf(u8, full_name, filter) == null and
                std.mem.indexOf(u8, test_case.name, filter) == null)
            {
                return true;
            }
        }

        return false;
    }

    fn runSuite(self: *Self, suite: framework.TestSuite) !u32 {
        std.debug.print("\n", .{});
        self.printSuiteBanner(suite.name);

        var failures: u32 = 0;

        for (suite.tests) |test_case| {
            if (self.shouldSkipTest(suite, test_case)) {
                continue;
            }

            var i: u32 = 0;
            while (i < self.config.iterations) : (i += 1) {
                const result = self.runTest(suite, test_case);
                try self.results.append(result);
                self.printResult(result);

                if (result.status == .failed) {
                    failures += 1;
                }
            }
        }

        return failures;
    }

    fn runTest(self: *Self, suite: framework.TestSuite, test_case: framework.TestCase) framework.TestResult {
        _ = self;

        const start = std.time.nanoTimestamp();

        // Run setup if present
        if (suite.setup) |setup| {
            setup() catch |err| {
                return .{
                    .name = test_case.name,
                    .category = suite.name,
                    .status = .failed,
                    .duration_ns = @intCast(std.time.nanoTimestamp() - start),
                    .message = @errorName(err),
                };
            };
        }

        // Run the test
        const result = if (test_case.run()) |_|
            framework.TestResult{
                .name = test_case.name,
                .category = suite.name,
                .status = .passed,
                .duration_ns = @intCast(std.time.nanoTimestamp() - start),
            }
        else |err|
            framework.TestResult{
                .name = test_case.name,
                .category = suite.name,
                .status = if (err == error.NotImplemented) .skipped else .failed,
                .duration_ns = @intCast(std.time.nanoTimestamp() - start),
                .message = @errorName(err),
            };

        // Run teardown if present
        if (suite.teardown) |teardown| {
            teardown();
        }

        return result;
    }

    fn printHeader(self: *Self) void {
        _ = self;
        std.debug.print("\n", .{});
        std.debug.print("================================================================\n", .{});
        std.debug.print("         BLAZE CONFORMANCE TEST SUITE (BLAZE-CTS)              \n", .{});
        std.debug.print("================================================================\n", .{});
        std.debug.print("\n", .{});
    }

    fn printSuiteBanner(self: *Self, name: []const u8) void {
        _ = self;
        std.debug.print("--- {s} ", .{name});
        // Pad with dashes to 60 chars
        const name_len = name.len + 5; // "--- " + name + " "
        var i: usize = name_len;
        while (i < 60) : (i += 1) {
            std.debug.print("-", .{});
        }
        std.debug.print("\n", .{});
    }

    fn printResult(self: *Self, result: framework.TestResult) void {
        _ = self;
        const symbol = switch (result.status) {
            .passed => "[PASS]",
            .failed => "[FAIL]",
            .skipped => "[SKIP]",
            .timeout => "[TIME]",
        };

        const color = switch (result.status) {
            .passed => "\x1b[32m",
            .failed => "\x1b[31m",
            .skipped => "\x1b[33m",
            .timeout => "\x1b[33m",
        };

        const duration_ms = @as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0;

        std.debug.print("  {s}{s}\x1b[0m {s}", .{ color, symbol, result.name });

        if (result.message) |msg| {
            std.debug.print(" - {s}", .{msg});
        }

        std.debug.print(" ({d:.2}ms)\n", .{duration_ms});
    }

    fn printSummary(self: *Self) void {
        var passed: u32 = 0;
        var failed: u32 = 0;
        var skipped: u32 = 0;
        var timeout: u32 = 0;

        for (self.results.items) |r| {
            switch (r.status) {
                .passed => passed += 1,
                .failed => failed += 1,
                .skipped => skipped += 1,
                .timeout => timeout += 1,
            }
        }

        const total = passed + failed + skipped + timeout;
        const elapsed = std.time.milliTimestamp() - self.start_time;

        std.debug.print("\n", .{});
        std.debug.print("================================================================\n", .{});
        std.debug.print("                    CONFORMANCE RESULTS                         \n", .{});
        std.debug.print("================================================================\n", .{});
        std.debug.print("  Passed:  \x1b[32m{d}\x1b[0m\n", .{passed});
        std.debug.print("  Failed:  \x1b[31m{d}\x1b[0m\n", .{failed});
        std.debug.print("  Skipped: \x1b[33m{d}\x1b[0m\n", .{skipped});
        if (timeout > 0) {
            std.debug.print("  Timeout: \x1b[33m{d}\x1b[0m\n", .{timeout});
        }
        std.debug.print("  Total:   {d}\n", .{total});
        std.debug.print("  Time:    {d}ms\n", .{elapsed});
        std.debug.print("================================================================\n", .{});

        if (failed > 0) {
            std.debug.print("\n\x1b[31mFailed tests:\x1b[0m\n", .{});
            for (self.results.items) |r| {
                if (r.status == .failed) {
                    std.debug.print("  - {s}.{s}", .{ r.category, r.name });
                    if (r.message) |msg| {
                        std.debug.print(": {s}", .{msg});
                    }
                    std.debug.print("\n", .{});
                }
            }
        }

        const status = if (failed == 0) "\x1b[32mPASSED\x1b[0m" else "\x1b[31mFAILED\x1b[0m";
        std.debug.print("\nOverall: {s}\n", .{status});
    }

    fn writeJunitXml(self: *Self, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = file.writer();

        try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        try writer.writeAll("<testsuites>\n");

        // Group by category
        var categories = std.StringHashMap(std.ArrayList(framework.TestResult)).init(self.allocator);
        defer {
            var iter = categories.valueIterator();
            while (iter.next()) |list| {
                list.deinit();
            }
            categories.deinit();
        }

        for (self.results.items) |result| {
            const gop = try categories.getOrPut(result.category);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(framework.TestResult).init(self.allocator);
            }
            try gop.value_ptr.append(result);
        }

        var cat_iter = categories.iterator();
        while (cat_iter.next()) |entry| {
            var suite_failures: u32 = 0;
            var suite_time: u64 = 0;
            for (entry.value_ptr.items) |r| {
                if (r.status == .failed) suite_failures += 1;
                suite_time += r.duration_ns;
            }

            try writer.print("  <testsuite name=\"{s}\" tests=\"{d}\" failures=\"{d}\" time=\"{d:.3}\">\n", .{
                entry.key_ptr.*,
                entry.value_ptr.items.len,
                suite_failures,
                @as(f64, @floatFromInt(suite_time)) / 1_000_000_000.0,
            });

            for (entry.value_ptr.items) |r| {
                try writer.print("    <testcase name=\"{s}\" time=\"{d:.3}\"", .{
                    r.name,
                    @as(f64, @floatFromInt(r.duration_ns)) / 1_000_000_000.0,
                });

                if (r.status == .failed) {
                    try writer.writeAll(">\n");
                    try writer.print("      <failure message=\"{s}\"/>\n", .{r.message orelse "Unknown error"});
                    try writer.writeAll("    </testcase>\n");
                } else if (r.status == .skipped) {
                    try writer.writeAll(">\n");
                    try writer.writeAll("      <skipped/>\n");
                    try writer.writeAll("    </testcase>\n");
                } else {
                    try writer.writeAll("/>\n");
                }
            }

            try writer.writeAll("  </testsuite>\n");
        }

        try writer.writeAll("</testsuites>\n");
    }

    fn writeJsonOutput(self: *Self, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = file.writer();

        try writer.writeAll("{\n  \"results\": [\n");

        for (self.results.items, 0..) |r, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.print("    {{\n      \"name\": \"{s}\",\n      \"category\": \"{s}\",\n      \"status\": \"{s}\",\n      \"duration_ms\": {d:.3}", .{
                r.name,
                r.category,
                @tagName(r.status),
                @as(f64, @floatFromInt(r.duration_ns)) / 1_000_000.0,
            });
            if (r.message) |msg| {
                try writer.print(",\n      \"message\": \"{s}\"", .{msg});
            }
            try writer.writeAll("\n    }");
        }

        try writer.writeAll("\n  ]\n}\n");
    }
};

/// Parses command line arguments into a RunnerConfig.
pub fn parseArgs(allocator: std.mem.Allocator) !RunnerConfig {
    var config = RunnerConfig{};

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip executable name
    _ = args.skip();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--filter") or std.mem.eql(u8, arg, "-f")) {
            config.filter = args.next();
        } else if (std.mem.eql(u8, arg, "--generate-golden")) {
            config.generate_golden = true;
        } else if (std.mem.eql(u8, arg, "--save-diffs")) {
            config.save_diffs = true;
        } else if (std.mem.eql(u8, arg, "--junit-output")) {
            config.junit_output = args.next();
        } else if (std.mem.eql(u8, arg, "--json-output")) {
            config.json_output = args.next();
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "--no-keep-going")) {
            config.keep_going = false;
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            if (args.next()) |n| {
                config.iterations = std.fmt.parseInt(u32, n, 10) catch 1;
            }
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            std.process.exit(0);
        }
    }

    return config;
}

fn printUsage() void {
    std.debug.print(
        \\BLAZE Conformance Test Suite (BLAZE-CTS)
        \\
        \\Usage: test-cts [OPTIONS]
        \\
        \\Options:
        \\  -f, --filter <PATTERN>    Run only tests matching pattern
        \\  --generate-golden         Generate/update golden images
        \\  --save-diffs              Save diff images on comparison failure
        \\  --junit-output <PATH>     Write JUnit XML results to file
        \\  --json-output <PATH>      Write JSON results to file
        \\  -v, --verbose             Enable verbose output
        \\  --no-keep-going           Stop on first failure
        \\  --iterations <N>          Run each test N times
        \\  -h, --help                Show this help message
        \\
        \\Examples:
        \\  test-cts                          Run all tests
        \\  test-cts --filter context         Run context tests only
        \\  test-cts --filter CTX-001         Run specific test
        \\  test-cts --generate-golden        Update golden images
        \\  test-cts --junit-output results.xml
        \\
    , .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try parseArgs(allocator);
    var runner = TestRunner.init(allocator, config);
    defer runner.deinit();

    const failures = try runner.run();

    if (failures > 0) {
        std.process.exit(1);
    }
}
