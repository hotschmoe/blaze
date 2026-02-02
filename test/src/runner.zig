//! BLAZE Conformance Test Suite - Test Runner
//!
//! Main entry point for running conformance tests. Supports filtering,
//! golden image generation, and various output formats.

const std = @import("std");
const framework = @import("framework.zig");

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

pub const RunnerConfig = struct {
    filter: ?[]const u8 = null,
    generate_golden: bool = false,
    save_diffs: bool = false,
    junit_output: ?[]const u8 = null,
    json_output: ?[]const u8 = null,
    min_priority: framework.Priority = .p2,
    verbose: bool = false,
    keep_going: bool = true,
    iterations: u32 = 1,
};

pub const TestRunner = struct {
    allocator: std.mem.Allocator,
    config: RunnerConfig,
    results: std.ArrayListUnmanaged(framework.TestResult),
    start_time: i64,

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

    pub fn init(allocator: std.mem.Allocator, config: RunnerConfig) TestRunner {
        return .{
            .allocator = allocator,
            .config = config,
            .results = .{},
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *TestRunner) void {
        self.results.deinit(self.allocator);
    }

    pub fn run(self: *TestRunner) !u32 {
        printHeader();

        var failures: u32 = 0;
        for (all_suites) |suite| {
            if (self.shouldSkipSuite(suite)) continue;

            const suite_failures = try self.runSuite(suite);
            failures += suite_failures;

            if (suite_failures > 0 and !self.config.keep_going) break;
        }

        self.printSummary();

        if (self.config.junit_output) |path| try self.writeJunitXml(path);
        if (self.config.json_output) |path| try self.writeJsonOutput(path);

        return failures;
    }

    fn shouldSkipSuite(self: *TestRunner, suite: framework.TestSuite) bool {
        const filter = self.config.filter orelse return false;

        if (std.mem.indexOf(u8, suite.name, filter) != null) return false;
        for (suite.tests) |test_case| {
            if (std.mem.indexOf(u8, test_case.name, filter) != null) return false;
        }
        return true;
    }

    fn shouldSkipTest(self: *TestRunner, suite: framework.TestSuite, test_case: framework.TestCase) bool {
        if (@intFromEnum(test_case.priority) > @intFromEnum(self.config.min_priority)) return true;

        if (self.config.filter) |filter| {
            // Check if filter matches test name or suite.test_name pattern
            if (std.mem.indexOf(u8, test_case.name, filter) != null) return false;
            if (std.mem.indexOf(u8, suite.name, filter) != null) return false;
            return true;
        }
        return false;
    }

    fn runSuite(self: *TestRunner, suite: framework.TestSuite) !u32 {
        std.debug.print("\n", .{});
        printSuiteBanner(suite.name);

        var failures: u32 = 0;
        for (suite.tests) |test_case| {
            if (self.shouldSkipTest(suite, test_case)) continue;

            for (0..self.config.iterations) |_| {
                const result = runTest(suite, test_case);
                try self.results.append(self.allocator, result);
                printResult(result);

                if (result.status == .failed) failures += 1;
            }
        }
        return failures;
    }

    fn runTest(suite: framework.TestSuite, test_case: framework.TestCase) framework.TestResult {
        const start = std.time.nanoTimestamp();

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

        defer if (suite.teardown) |teardown| teardown();

        return if (test_case.run()) |_|
            .{
                .name = test_case.name,
                .category = suite.name,
                .status = .passed,
                .duration_ns = @intCast(std.time.nanoTimestamp() - start),
            }
        else |err|
            .{
                .name = test_case.name,
                .category = suite.name,
                .status = if (err == error.NotImplemented) .skipped else .failed,
                .duration_ns = @intCast(std.time.nanoTimestamp() - start),
                .message = @errorName(err),
            };
    }

    fn printHeader() void {
        std.debug.print(
            \\
            \\================================================================
            \\         BLAZE CONFORMANCE TEST SUITE (BLAZE-CTS)
            \\================================================================
            \\
        , .{});
    }

    fn printSuiteBanner(name: []const u8) void {
        std.debug.print("--- {s} ", .{name});
        for (name.len + 5..60) |_| std.debug.print("-", .{});
        std.debug.print("\n", .{});
    }

    fn printResult(result: framework.TestResult) void {
        const symbol, const color = switch (result.status) {
            .passed => .{ "[PASS]", "\x1b[32m" },
            .failed => .{ "[FAIL]", "\x1b[31m" },
            .skipped => .{ "[SKIP]", "\x1b[33m" },
            .timeout => .{ "[TIME]", "\x1b[33m" },
        };

        const duration_ms = @as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0;
        std.debug.print("  {s}{s}\x1b[0m {s}", .{ color, symbol, result.name });
        if (result.message) |msg| std.debug.print(" - {s}", .{msg});
        std.debug.print(" ({d:.2}ms)\n", .{duration_ms});
    }

    fn printSummary(self: *TestRunner) void {
        var counts = [4]u32{ 0, 0, 0, 0 };
        for (self.results.items) |r| counts[@intFromEnum(r.status)] += 1;

        const passed, const failed, const skipped, const timeout = .{ counts[0], counts[1], counts[2], counts[3] };
        const total = passed + failed + skipped + timeout;
        const elapsed = std.time.milliTimestamp() - self.start_time;

        std.debug.print(
            \\
            \\================================================================
            \\                    CONFORMANCE RESULTS
            \\================================================================
            \\  Passed:  {[green]s}{[passed]d}{[reset]s}
            \\  Failed:  {[red]s}{[failed]d}{[reset]s}
            \\  Skipped: {[yellow]s}{[skipped]d}{[reset]s}
        , .{
            .green = "\x1b[32m",
            .red = "\x1b[31m",
            .yellow = "\x1b[33m",
            .reset = "\x1b[0m",
            .passed = passed,
            .failed = failed,
            .skipped = skipped,
        });

        if (timeout > 0) std.debug.print("  Timeout: \x1b[33m{d}\x1b[0m\n", .{timeout});
        std.debug.print("  Total:   {d}\n  Time:    {d}ms\n================================================================\n", .{ total, elapsed });

        if (failed > 0) {
            std.debug.print("\n\x1b[31mFailed tests:\x1b[0m\n", .{});
            for (self.results.items) |r| {
                if (r.status == .failed) {
                    std.debug.print("  - {s}.{s}", .{ r.category, r.name });
                    if (r.message) |msg| std.debug.print(": {s}", .{msg});
                    std.debug.print("\n", .{});
                }
            }
        }

        std.debug.print("\nOverall: {s}\n", .{if (failed == 0) "\x1b[32mPASSED\x1b[0m" else "\x1b[31mFAILED\x1b[0m"});
    }

    fn writeJunitXml(self: *TestRunner, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<testsuites>\n");

        var categories = std.StringHashMapUnmanaged(std.ArrayListUnmanaged(framework.TestResult)){};
        defer {
            var iter = categories.valueIterator();
            while (iter.next()) |list| list.deinit(self.allocator);
            categories.deinit(self.allocator);
        }

        for (self.results.items) |result| {
            const gop = try categories.getOrPut(self.allocator, result.category);
            if (!gop.found_existing) gop.value_ptr.* = .{};
            try gop.value_ptr.append(self.allocator, result);
        }

        var cat_iter = categories.iterator();
        while (cat_iter.next()) |entry| {
            var suite_failures: u32 = 0;
            var suite_time: u64 = 0;
            for (entry.value_ptr.items) |r| {
                if (r.status == .failed) suite_failures += 1;
                suite_time += r.duration_ns;
            }

            const suite_header = try std.fmt.allocPrint(self.allocator, "  <testsuite name=\"{s}\" tests=\"{d}\" failures=\"{d}\" time=\"{d:.3}\">\n", .{
                entry.key_ptr.*, entry.value_ptr.items.len, suite_failures, @as(f64, @floatFromInt(suite_time)) / 1e9,
            });
            defer self.allocator.free(suite_header);
            try file.writeAll(suite_header);

            for (entry.value_ptr.items) |r| {
                const testcase = try std.fmt.allocPrint(self.allocator, "    <testcase name=\"{s}\" time=\"{d:.3}\"", .{
                    r.name, @as(f64, @floatFromInt(r.duration_ns)) / 1e9,
                });
                defer self.allocator.free(testcase);
                try file.writeAll(testcase);

                switch (r.status) {
                    .failed => {
                        const fail_msg = try std.fmt.allocPrint(self.allocator, ">\n      <failure message=\"{s}\"/>\n    </testcase>\n", .{r.message orelse "Unknown error"});
                        defer self.allocator.free(fail_msg);
                        try file.writeAll(fail_msg);
                    },
                    .skipped => try file.writeAll(">\n      <skipped/>\n    </testcase>\n"),
                    else => try file.writeAll("/>\n"),
                }
            }
            try file.writeAll("  </testsuite>\n");
        }
        try file.writeAll("</testsuites>\n");
    }

    fn writeJsonOutput(self: *TestRunner, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll("{\n  \"results\": [\n");
        for (self.results.items, 0..) |r, i| {
            if (i > 0) try file.writeAll(",\n");
            const entry = try std.fmt.allocPrint(self.allocator,
                \\    {{
                \\      "name": "{s}",
                \\      "category": "{s}",
                \\      "status": "{s}",
                \\      "duration_ms": {d:.3}
            , .{ r.name, r.category, @tagName(r.status), @as(f64, @floatFromInt(r.duration_ns)) / 1e6 });
            defer self.allocator.free(entry);
            try file.writeAll(entry);

            if (r.message) |msg| {
                const msg_str = try std.fmt.allocPrint(self.allocator, ",\n      \"message\": \"{s}\"", .{msg});
                defer self.allocator.free(msg_str);
                try file.writeAll(msg_str);
            }
            try file.writeAll("\n    }");
        }
        try file.writeAll("\n  ]\n}\n");
    }
};

pub fn parseArgs(allocator: std.mem.Allocator) !RunnerConfig {
    var config = RunnerConfig{};
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // executable name

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
            if (args.next()) |n| config.iterations = std.fmt.parseInt(u32, n, 10) catch 1;
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
        \\Usage: blaze-cts [OPTIONS]
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
