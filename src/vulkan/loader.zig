const std = @import("std");
const vk = @import("vulkan");
const builtin = @import("builtin");

pub const LoaderError = error{
    LibraryNotFound,
    SymbolNotFound,
    InitializationFailed,
};

pub const Loader = struct {
    handle: std.DynLib,
    vkGetInstanceProcAddr: vk.PfnGetInstanceProcAddr,

    const library_names = switch (builtin.os.tag) {
        .linux, .freebsd, .openbsd, .netbsd => &[_][:0]const u8{
            "libvulkan.so.1",
            "libvulkan.so",
        },
        .windows => &[_][:0]const u8{
            "vulkan-1.dll",
        },
        .macos => &[_][:0]const u8{
            "libvulkan.1.dylib",
            "libvulkan.dylib",
            "libMoltenVK.dylib",
        },
        else => &[_][:0]const u8{},
    };

    pub fn init() LoaderError!Loader {
        for (library_names) |name| {
            var lib = std.DynLib.open(name) catch continue;
            const get_proc = lib.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr") orelse {
                lib.close();
                continue;
            };
            return .{
                .handle = lib,
                .vkGetInstanceProcAddr = get_proc,
            };
        }
        return error.LibraryNotFound;
    }

    pub fn deinit(self: *Loader) void {
        self.handle.close();
        self.* = undefined;
    }

    pub fn getBaseFunctions(self: Loader) vk.BaseWrapper {
        return vk.BaseWrapper.load(self.vkGetInstanceProcAddr);
    }
};
