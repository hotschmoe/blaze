//! Cross-platform SwiftShader downloader for CI/testing
//!
//! Downloads Google's SwiftShader software Vulkan implementation for
//! running Vulkan tests without hardware GPU.
//!
//! Usage:
//!   zig build fetch-swiftshader
//!
//! After download, set VK_ICD_FILENAMES to use SwiftShader:
//!   Windows: set VK_ICD_FILENAMES=%CD%\.swiftshader\vk_swiftshader_icd.json
//!   macOS:   export VK_ICD_FILENAMES=$PWD/.swiftshader/vk_swiftshader_icd.json

const std = @import("std");
const builtin = @import("builtin");

const Config = struct {
    const output_dir = ".swiftshader";

    // Pre-built SwiftShader binaries from rokuz/swiftshader_binaries
    const base_url = "https://github.com/rokuz/swiftshader_binaries/releases/download/release_1";

    const windows_x64_url = base_url ++ "/swiftshader_win_x86_64.zip";
    const windows_arm64_url = base_url ++ "/swiftshader_win_arm64.zip";
    const windows_lib = "vk_swiftshader.dll";
    const windows_zip_path = "swiftshader/win";

    const macos_x64_url = base_url ++ "/swiftshader_macos_x86_64.zip";
    const macos_arm64_url = base_url ++ "/swiftshader_macos_arm64.zip";
    const macos_lib = "libvk_swiftshader.dylib";
    const macos_zip_path = "swiftshader/macos";
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (builtin.os.tag == .linux) {
        printLinuxInstructions();
        return;
    }

    const target = getTarget();
    if (target.url == null) {
        std.debug.print(
            \\SwiftShader download not available for this platform/architecture.
            \\
            \\Supported platforms:
            \\  - Windows x86_64 and ARM64
            \\  - macOS x86_64 and ARM64
            \\  - Linux: Use lavapipe (see below)
            \\
        , .{});
        printLinuxInstructions();
        return;
    }

    std.debug.print("Fetching SwiftShader for {s}-{s}...\n", .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
    });

    const cwd = std.fs.cwd();

    cwd.makeDir(Config.output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const zip_path = try std.fmt.allocPrint(allocator, "{s}/swiftshader.zip", .{Config.output_dir});
    defer allocator.free(zip_path);

    std.debug.print("Downloading SwiftShader...\n", .{});
    try downloadFile(allocator, target.url.?, zip_path);

    std.debug.print("Extracting...\n", .{});
    try extractSwiftShader(allocator, zip_path, target);

    cwd.deleteFile(zip_path) catch {};

    std.debug.print("Creating ICD manifest...\n", .{});
    try createIcdManifest(allocator, target.lib);

    const abs_path = try cwd.realpathAlloc(allocator, Config.output_dir);
    defer allocator.free(abs_path);

    std.debug.print(
        \\
        \\SwiftShader downloaded to {s}/
        \\
        \\To use SwiftShader, set the environment variable:
        \\
    , .{Config.output_dir});

    if (builtin.os.tag == .windows) {
        std.debug.print("  set VK_ICD_FILENAMES={s}\\vk_swiftshader_icd.json\n", .{abs_path});
    } else {
        std.debug.print("  export VK_ICD_FILENAMES={s}/vk_swiftshader_icd.json\n", .{abs_path});
    }

    std.debug.print(
        \\
        \\Then run tests:
        \\  zig build test
        \\
    , .{});
}

fn printLinuxInstructions() void {
    std.debug.print(
        \\
        \\Linux: Use lavapipe (Mesa software Vulkan) instead of SwiftShader.
        \\Lavapipe is well-maintained and packaged in all major distros.
        \\
        \\Installation:
        \\  Ubuntu/Debian: sudo apt install mesa-vulkan-drivers
        \\  Fedora:        sudo dnf install mesa-vulkan-drivers
        \\  Arch:          sudo pacman -S vulkan-swrast
        \\  openSUSE:      sudo zypper install Mesa-vulkan-device-select
        \\
        \\Usage:
        \\  export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json
        \\  zig build test
        \\
        \\Note: The exact ICD path may vary. Find it with:
        \\  find /usr -name "*lvp*icd*.json" 2>/dev/null
        \\
    , .{});
}

const Target = struct {
    url: ?[]const u8,
    lib: []const u8,
    zip_path: []const u8,
    arch_dir: []const u8,
};

fn getTarget() Target {
    return switch (builtin.os.tag) {
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => .{
                .url = Config.windows_x64_url,
                .lib = Config.windows_lib,
                .zip_path = Config.windows_zip_path,
                .arch_dir = "x86_64",
            },
            .aarch64 => .{
                .url = Config.windows_arm64_url,
                .lib = Config.windows_lib,
                .zip_path = Config.windows_zip_path,
                .arch_dir = "arm64",
            },
            else => .{ .url = null, .lib = "", .zip_path = "", .arch_dir = "" },
        },
        .macos => switch (builtin.cpu.arch) {
            .x86_64 => .{
                .url = Config.macos_x64_url,
                .lib = Config.macos_lib,
                .zip_path = Config.macos_zip_path,
                .arch_dir = "x86_64",
            },
            .aarch64 => .{
                .url = Config.macos_arm64_url,
                .lib = Config.macos_lib,
                .zip_path = Config.macos_zip_path,
                .arch_dir = "arm64",
            },
            else => .{ .url = null, .lib = "", .zip_path = "", .arch_dir = "" },
        },
        else => .{ .url = null, .lib = "", .zip_path = "", .arch_dir = "" },
    };
}

fn downloadFile(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8) !void {
    const curl_args = [_][]const u8{ "curl", "-fsSL", "-o", output_path, url };
    const wget_args = [_][]const u8{ "wget", "-q", "-O", output_path, url };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &curl_args,
    }) catch {
        const wget_result = try std.process.Child.run(.{
            .allocator = allocator,
            .argv = &wget_args,
        });
        defer allocator.free(wget_result.stdout);
        defer allocator.free(wget_result.stderr);

        if (wget_result.term.Exited != 0) {
            std.debug.print("Download failed. stderr: {s}\n", .{wget_result.stderr});
            return error.DownloadFailed;
        }
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("Download failed. stderr: {s}\n", .{result.stderr});
        return error.DownloadFailed;
    }
}

fn extractSwiftShader(allocator: std.mem.Allocator, zip_path: []const u8, target: Target) !void {
    const lib_in_zip = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
        target.zip_path,
        target.arch_dir,
        target.lib,
    });
    defer allocator.free(lib_in_zip);

    const output_lib = try std.fmt.allocPrint(allocator, "{s}/{s}", .{
        Config.output_dir,
        target.lib,
    });
    defer allocator.free(output_lib);

    if (builtin.os.tag == .windows) {
        const args = [_][]const u8{
            "tar", "-xf", zip_path, "-C", Config.output_dir, "--strip-components=3", lib_in_zip,
        };
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &args,
        }) catch {
            const ps_cmd = try std.fmt.allocPrint(allocator,
                \\Expand-Archive -Path '{s}' -DestinationPath '{s}' -Force; Move-Item -Path '{s}\{s}' -Destination '{s}' -Force
            , .{ zip_path, Config.output_dir, Config.output_dir, lib_in_zip, output_lib });
            defer allocator.free(ps_cmd);

            const ps_args = [_][]const u8{ "powershell", "-Command", ps_cmd };
            const ps_result = try std.process.Child.run(.{
                .allocator = allocator,
                .argv = &ps_args,
            });
            defer allocator.free(ps_result.stdout);
            defer allocator.free(ps_result.stderr);

            if (ps_result.term.Exited != 0) {
                std.debug.print("Extraction failed. stderr: {s}\n", .{ps_result.stderr});
                return error.ExtractionFailed;
            }
            return;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("Extraction failed. stderr: {s}\n", .{result.stderr});
            return error.ExtractionFailed;
        }
    } else {
        const temp_dir = try std.fmt.allocPrint(allocator, "{s}/temp_extract", .{Config.output_dir});
        defer allocator.free(temp_dir);

        const unzip_args = [_][]const u8{ "unzip", "-q", "-o", zip_path, "-d", temp_dir };
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &unzip_args,
        });

        if (result) |r| {
            defer allocator.free(r.stdout);
            defer allocator.free(r.stderr);
            if (r.term.Exited != 0) {
                std.debug.print("Extraction failed. stderr: {s}\n", .{r.stderr});
                return error.ExtractionFailed;
            }
        } else |_| {
            return error.ExtractionFailed;
        }

        const src_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ temp_dir, lib_in_zip });
        defer allocator.free(src_path);

        const mv_args = [_][]const u8{ "mv", src_path, output_lib };
        _ = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &mv_args,
        }) catch {};

        const rm_args = [_][]const u8{ "rm", "-rf", temp_dir };
        _ = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &rm_args,
        }) catch {};
    }
}

fn createIcdManifest(allocator: std.mem.Allocator, lib_name: []const u8) !void {
    const cwd = std.fs.cwd();
    const dir_path = try cwd.realpathAlloc(allocator, Config.output_dir);
    defer allocator.free(dir_path);

    const lib_path = if (builtin.os.tag == .windows)
        try std.fmt.allocPrint(allocator, "{s}\\{s}", .{ dir_path, lib_name })
    else
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, lib_name });
    defer allocator.free(lib_path);

    const manifest = try std.fmt.allocPrint(allocator,
        \\{{
        \\    "file_format_version": "1.0.0",
        \\    "ICD": {{
        \\        "library_path": "{s}",
        \\        "api_version": "1.3.0"
        \\    }}
        \\}}
        \\
    , .{lib_path});
    defer allocator.free(manifest);

    var output_dir = try cwd.openDir(Config.output_dir, .{});
    defer output_dir.close();

    const file = try output_dir.createFile("vk_swiftshader_icd.json", .{});
    defer file.close();
    try file.writeAll(manifest);
}
